import datetime
import json
import logging
import os

import aws_eden_core.methods
import boto3
from boto3.dynamodb.conditions import Key

# set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)
logger.info('Loading eden_core')

dynamodb_client = boto3.client('dynamodb')
dynamodb_resource = boto3.resource('dynamodb')

route53 = boto3.client('route53')
ecr = boto3.client('ecr')
ecs = boto3.client('ecs')
s3 = boto3.resource('s3')
elbv2 = boto3.client('elbv2')

table_name = os.environ['EDEN_TABLE']


def fetch_profile(profile_name: str):
    try:
        response = dynamodb_client.describe_table(TableName=table_name)
        table_status = response['Table']['TableStatus']
    except Exception as e:
        if hasattr(e, 'response') and 'Error' in e.response:
            if e.response['Error']['Code'] != 'ResourceNotFoundException':
                logger.error(f"Unknown exception raised on DescribeTable API: {e.response}")
                return None, generate_response('Unknown exception', 501)

        return None, generate_response(f"Table {table_name} does not exist, try running \"eden config --push\"", 400)

    if table_status != 'ACTIVE':
        return None, generate_response(f"Table {table_name} status is \"{table_status}\", try again later", 501)

    table = dynamodb_resource.Table(table_name)

    try:
        r = table.query(
            KeyConditionExpression=Key('type').eq('_profile') & Key('name').eq(profile_name)
        )
    except Exception as e:
        if hasattr(e, 'response') and 'Error' in e.response:
            error = e.response['Error']['Message']
            logger.error(error)
            return None, generate_response(error, 501)
        else:
            error = f"Unknown exception raised: {e}"
            logger.error(error)
            return None, generate_response(error, 501)

    if 'Items' not in r or len(r['Items']) == 0:
        error = f"Profile {profile_name} not found in remote table!"
        logger.warning(error)
        return None, generate_response(error, 501)
    elif len(r['Items']) != 1:
        error = f"Got multiple profiles for profile name {profile_name} from remote table!"
        logger.warning(error)
        return None, generate_response(error, 501)
    elif 'profile' not in r['Items'][0]:
        error = f"Profile {profile_name} does not contain any parameters!"
        logger.warning(error)
        return None, generate_response(error, 501)

    profile = r['Items'][0]['profile']

    try:
        profile_json = json.loads(profile)
    except json.JSONDecodeError as e:
        error = f"JSON decode error: {e}"
        logger.error(error)
        return None, generate_response(error, 501)

    return profile_json, None


def create_env(name, image_uri, profile_name, config):
    try:
        r = aws_eden_core.methods.create_env(name, image_uri, config)
    except Exception as e:
        logger.error(e)
        return None, generate_response(f"Exception caught", 501)

    table = dynamodb_resource.Table(table_name)

    try:
        table.put_item(
            Item={
                'type': profile_name,
                'name': name,
                'type_name': f"{profile_name}_{name}",
                'last_updated_time': str(datetime.datetime.now().timestamp()),
                'endpoint': r['cname'],
            }
        )
    except Exception as e:
        if hasattr(e, 'response') and 'Error' in e.response:
            error = e.response['Error']['Message']
            logger.error(error)
            return generate_response(error, 501), True
        else:
            error = f"Unknown exception raised: {e}"
            logger.error(error)
            return generate_response(error, 501), True

    return r, False


# @app.route('/api/v1/delete')
def delete_env(name, profile_name, config):
    try:
        r = aws_eden_core.methods.delete_env(name, config)
    except Exception as e:
        logger.error(e)
        return generate_response("Exception caught", 501), True

    table = dynamodb_resource.Table(table_name)

    try:
        table.delete_item(
            Key={
                'type': profile_name,
                'name': name,
            },
        )
    except Exception as e:
        if hasattr(e, 'response') and 'Error' in e.response:
            error = e.response['Error']['Message']
            logger.error(error)
            return generate_response(error, 501), True
        else:
            error = f"Unknown exception raised: {e}"
            logger.error(error)
            return generate_response(error, 501), True

    return r, False


def generate_response(message, status_code, additional_fields=None):
    if additional_fields is None:
        additional_fields = {}

    if status_code >= 400:
        status = 'error'
    else:
        status = 'ok'

    ret_dict = {
            'status': status,
            'message': message,
    }

    for k, v in additional_fields.items():
        ret_dict[k] = v

    return {
        'isBase64Encoded': False,
        'statusCode': status_code,
        'headers': {},
        'body': json.dumps(ret_dict)
    }


def validate_params(query_string_parameters, check_params: list):
    if query_string_parameters is None:
        return generate_response(f"Necessary query string parameters not specified: {' '.join(check_params)}", 400)

    for p in check_params:
        if p not in query_string_parameters or query_string_parameters[p] is None:
            return generate_response(f"Necessary query string parameters not specified: {p}", 400)

    return None


def lambda_handler(event, context):
    profile_name = 'default'
    if event['queryStringParameters'] is not None:
        if 'profile' in event['queryStringParameters'] and event['queryStringParameters']['profile'] is not None:
            profile_name = event['queryStringParameters']['profile']

    config, e = fetch_profile(profile_name)

    if e:
        return e

    if event['resource'] == '/api/v1/create':
        error_response = validate_params(event['queryStringParameters'], ["name", "image_uri"])

        if error_response is not None:
            return error_response

        r, e = create_env(
            event['queryStringParameters']['name'],
            event['queryStringParameters']['image_uri'],
            profile_name,
            config,
        )

        if e:
            return r

        return generate_response("successfully created", 200, additional_fields=r)

    elif event['resource'] == '/api/v1/delete':
        e = validate_params(event['queryStringParameters'], ["name"])

        if e is not None:
            return e

        r, e = delete_env(
            event['queryStringParameters']['name'],
            profile_name,
            config,
        )

        if e:
            return r

        return generate_response("successfully deleted", 200, additional_fields=r)

    else:
        pass

    return

