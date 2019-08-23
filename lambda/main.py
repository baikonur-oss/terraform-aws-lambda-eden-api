import logging

import boto3
import serverless_wsgi
from flask import Flask, request, jsonify

import eden_core.methods

# set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)
logger.info('Loading eden_core')

route53 = boto3.client('route53')
ecr = boto3.client('ecr')
ecs = boto3.client('ecs')
s3 = boto3.resource('s3')
elbv2 = boto3.client('elbv2')

app = Flask(__name__)


@app.route('/api/v1/create')
def create_env():
    if 'branch' not in request.args or 'image_uri' not in request.args:
        return jsonify({
            'status': 'error',
            'reason': 'Insufficient query parameters',
            'code':   400,
        }), 400

    branch: str = request.args.get('branch')
    image_uri: str = request.args.get('image_uri')
    errors = eden_core.methods.create_env(branch, image_uri, None)

    if not errors:
        return jsonify({
            'status': 'ok',
            'code':   200
        }), 200
    else:
        return jsonify({
            'status': 'error',
            'code':   501
        }), 501


@app.route('/api/v1/delete')
def delete_env():
    if 'branch' not in request.args:
        return jsonify({
            'status': 'error',
            'reason': 'Insufficient query parameters',
            'code':   400,
        }), 400

    branch: str = request.args.get('branch')
    errors = eden_core.methods.delete_env(branch, None)

    if not errors:
        return jsonify({
            'status': 'ok',
            'code':   200
        }), 200
    else:
        return jsonify({
            'status': 'error',
            'code':   501
        }), 501


def lambda_handler(event, context):
    return serverless_wsgi.handle_request(app, event, context)


if __name__ == '__main__':
    app.run()
