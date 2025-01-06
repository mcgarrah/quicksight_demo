import botocore
import requests
import botocore.session
import os

#Okta Config
#Okta Domain mapped from environment variable
okta_group_url= os.environ['okta_domain']+"/api/v1/apps/"+os.environ['okta_quicksight_app_id']+"/groups"

#Okta API Request Header
headers = {
        'accept': 'application/json',
        'authorization' : 'SSWS '+ os.environ['okta_api_token'],
        'content-type': 'application/json'
        }

#Quicksight Name 
default_namespace = os.environ['namespace']

def lambda_handler(event, context):
    
    # Get AWS Region from Lambda Context
    aws_region = context.invoked_function_arn.split(':')[3]
    # Get AWS Account ID from Lambda Context
    account_id = context.invoked_function_arn.split(':')[4]
    
    print(aws_region,'-',account_id)
    
    session = botocore.session.get_session()
    client = session.create_client("quicksight", region_name= aws_region)
    
    okta_group_list = []
    qs_group_list=[]

    #Okta Response
    okta_response = (requests.get(okta_group_url, headers=headers)).json()

    #r = okta_response.json()

    for group in okta_response:
        group_url = group['_links']['group']['href']
        group_info = (requests.get(group_url, headers=headers)).json()
        okta_group_list.append('Okta-'+group_info['profile']['name'])
    
    
    #Quicksight Response
    qs_response = client.list_groups(AwsAccountId = account_id, Namespace=default_namespace)
    
    for group in qs_response['GroupList']:
        if 'Description' in list(group.keys()) and group['Description'] == 'Okta':
            qs_group_list.append(group["GroupName"])
    
    #--Create Group--#
    qs_create_group_list = list(sorted(set(okta_group_list) - set(qs_group_list)))
    if len(qs_create_group_list) > 0:
        for i in range(0,len(qs_create_group_list)):
            client.create_group(AwsAccountId = account_id, Namespace=default_namespace, GroupName=qs_create_group_list[i], Description='Okta')
            #print(f"Group Created:{qs_create_group_list[i]}")

    #--Delete Groups only from Okta--#
    qs_delete_group_list = list(sorted(set(qs_group_list) - set(okta_group_list)))
    if len(qs_delete_group_list) > 0:
        for i in range(0,len(qs_delete_group_list)):
            client.delete_group(AwsAccountId = account_id, Namespace=default_namespace, GroupName=qs_delete_group_list[i])
            #print(f"Group Deleted:{qs_delete_group_list[i]}")