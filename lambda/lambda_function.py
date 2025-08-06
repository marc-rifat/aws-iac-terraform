import json
import boto3
import logging
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """
    AWS Lambda function to create S3 bucket and upload a test file
    """
    
    bucket_name = 'iac-testing-440225444492340'
    file_name = 'result.txt'
    file_content = 'test passed'
    
    s3_client = boto3.client('s3')
    
    try:
        # Create S3 bucket
        logger.info(f"Creating S3 bucket: {bucket_name}")
        
        # Get current region
        region = boto3.Session().region_name or 'us-east-1'
        
        if region == 'us-east-1':
            # us-east-1 doesn't need LocationConstraint
            s3_client.create_bucket(Bucket=bucket_name)
        else:
            s3_client.create_bucket(
                Bucket=bucket_name,
                CreateBucketConfiguration={'LocationConstraint': region}
            )
        
        logger.info(f"Successfully created bucket: {bucket_name}")
        
        # Upload file to bucket
        logger.info(f"Uploading file: {file_name}")
        s3_client.put_object(
            Bucket=bucket_name,
            Key=file_name,
            Body=file_content,
            ContentType='text/plain'
        )
        
        logger.info(f"Successfully uploaded file: {file_name}")
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'POST, GET, OPTIONS'
            },
            'body': json.dumps({
                'message': 'Success',
                'bucket_name': bucket_name,
                'file_name': file_name,
                'file_content': file_content,
                'region': region
            })
        }
        
    except ClientError as e:
        error_code = e.response['Error']['Code']
        error_message = e.response['Error']['Message']
        
        if error_code == 'BucketAlreadyOwnedByYou':
            logger.info(f"Bucket {bucket_name} already exists and is owned by you")
            # Still try to upload the file
            try:
                s3_client.put_object(
                    Bucket=bucket_name,
                    Key=file_name,
                    Body=file_content,
                    ContentType='text/plain'
                )
                return {
                    'statusCode': 200,
                    'headers': {
                        'Content-Type': 'application/json',
                        'Access-Control-Allow-Origin': '*',
                        'Access-Control-Allow-Headers': 'Content-Type',
                        'Access-Control-Allow-Methods': 'POST, GET, OPTIONS'
                    },
                    'body': json.dumps({
                        'message': 'Success - bucket already existed',
                        'bucket_name': bucket_name,
                        'file_name': file_name,
                        'file_content': file_content
                    })
                }
            except Exception as upload_error:
                logger.error(f"Error uploading file: {str(upload_error)}")
                return {
                    'statusCode': 500,
                    'headers': {
                        'Content-Type': 'application/json',
                        'Access-Control-Allow-Origin': '*'
                    },
                    'body': json.dumps({
                        'error': f'Failed to upload file: {str(upload_error)}'
                    })
                }
        else:
            logger.error(f"Error creating bucket: {error_code} - {error_message}")
            return {
                'statusCode': 500,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({
                    'error': f'Failed to create bucket: {error_message}'
                })
            }
    
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': f'Unexpected error: {str(e)}'
            })
        }