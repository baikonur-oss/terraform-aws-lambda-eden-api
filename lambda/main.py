import json
import logging

import boto3
import botocore
import serverless_wsgi
from flask import Flask, request, jsonify, g

import aws_eden_core.methods

# set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)
logger.info('Loading eden_core')

dynamodb = boto3.client('dynamodb')
route53 = boto3.client('route53')
ecr = boto3.client('ecr')
ecs = boto3.client('ecs')
s3 = boto3.resource('s3')
elbv2 = boto3.client('elbv2')

table_name = 'eden'

app = Flask(__name__)


@app.before_request
def configure():
    if 'profile' not in request.args:
        g.profile = 'default'
    else:
        g.profile = request.args['profile']

    try:
        response = dynamodb.describe_table(TableName=table_name)
        table_status = response['Table']['TableStatus']
    except Exception as e:
        if hasattr(e, 'response') and 'Error' in e.response:
            if e.response['Error']['Code'] != 'ResourceNotFoundException':
                logger.error(f"Unknown exception raised on DescribeTable API: {e.response}")
                return jsonify({
                    'status': 'error',
                    'errors': 'Unknown exception',
                }), 501

        return jsonify({
                    'status': 'error',
                    'errors': f"Table {table_name} does not exist, try running \"eden config --push\"",
                }), 501

    if table_status != 'ACTIVE':
        return jsonify({
                    'status': 'error',
                    'errors': f"Table {table_name} status is \"{table_status}\", try again later",
                }), 501

    r = dynamodb.get_item(
        TableName='string',
        Key={
            'env_name': {
                'S': f"_profile_{g.profile}",
            }
        },
    )

    if 'Item' in r:
        if 'profile' in r['Item']:
            try:
                g.config = json.loads(r['Item']['profile'])
            except json.JSONDecodeError:
                logger.error(f"Profile {g.profile} is invalid: {r['Item']['profile']}")
                return jsonify({
                    'status': 'error',
                    'errors': f"Profile {g.profile} is invalid",
                }), 501
        else:
            return jsonify({
                'status': 'error',
                'errors': f"Profile {g.profile} exists, but is empty",
            }), 501
    else:
        return jsonify({
            'status': 'error',
            'errors': f"Profile {g.profile} not found",
        }), 404


@app.route('/api/v1/create')
def create_env():
    if 'name' not in request.args or 'image_uri' not in request.args:
        return jsonify({
            'status': 'error',
            'reason': 'Insufficient query parameters',
        }), 400

    name: str = request.args.get('name')
    image_uri: str = request.args.get('image_uri')
    errors = aws_eden_core.methods.create_env(name, image_uri, g.config)

    if not errors:
        return jsonify({
            'status': 'ok',
        }), 200
    else:
        return jsonify({
            'status': 'error',
            'errors': errors,
        }), 501


@app.route('/api/v1/delete')
def delete_env():
    if 'name' not in request.args:
        return jsonify({
            'status': 'error',
            'reason': 'Insufficient query parameters',
        }), 400

    name: str = request.args.get('name')
    errors = aws_eden_core.methods.delete_env(name, g.config)

    if not errors:
        return jsonify({
            'status': 'ok',
        }), 200
    else:
        return jsonify({
            'status': 'error',
            'errors': errors,
        }), 501


def lambda_handler(event, context):
    return serverless_wsgi.handle_request(app, event, context)


if __name__ == '__main__':
    app.run()
