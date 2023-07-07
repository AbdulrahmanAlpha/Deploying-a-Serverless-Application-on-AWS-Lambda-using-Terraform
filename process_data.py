import boto3
import json

s3 = boto3.client('s3')
dynamodb = boto3.client('dynamodb')

def lambda_handler(event, context):
    # Get the S3 bucket and key from the event
    bucket_name = event['Records'][0]['s3']['bucket']['name']
    object_key = event['Records'][0]['s3']['object']['key']

    # Read the data from the S3 object
    response = s3.get_object(Bucket=bucket_name, Key=object_key)
    data = response['Body'].read().decode('utf-8')

    # Process the data
    processed_data = data.upper()

    # Write the processed data to the DynamoDB table
    item = {
        'id': {'S': object_key},
        'data': {'S': processed_data}
    }
    dynamodb.put_item(TableName='processed-data', Item=item)

    # Return a success message
    return {
        'statusCode': 200,
        'body': json.dumps('Data processed successfully!')
    }