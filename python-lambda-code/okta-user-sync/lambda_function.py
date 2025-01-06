import botocore
import requests
import botocore.session
import os


#Okta Config
#Get All users from Okta for quickisght app only: 
qs_app_id_on_okta = os.environ['okta_quicksight_app_id']

#Okta url 
all_users_url=os.environ['okta_domain']+'/api/v1/apps/'+qs_app_id_on_okta+"/users?"

#URL to get all Quicksight app groups mapped in Okta
okta_qs_app_group_url= os.environ['okta_domain']+"/api/v1/apps/"+qs_app_id_on_okta+"/groups"
        
#Okta API Request Header
headers = {
        'accept': 'application/json',
        'authorization' : 'SSWS '+ os.environ['okta_api_token'],
        'content-type': 'application/json'
        }


def lambda_handler(event, context):
    
        #Quicksight config
        default_namespace = os.environ['namespace']
        aws_region = context.invoked_function_arn.split(':')[3]
        account_id = context.invoked_function_arn.split(':')[4]
        session = botocore.session.get_session()
        qs_client = session.create_client("quicksight", region_name= aws_region)
        
        
        session = botocore.session.get_session()
        iam_client = session.create_client("iam", region_name= aws_region)

        quicksight_iam_role_dict = {}
        okta_qs_app_group_list=[]

        #Okta Response
        okta_qs_group_response = (requests.get(okta_qs_app_group_url, headers=headers)).json()
        okta_qs_users_response = (requests.get(all_users_url, headers=headers)).json()

        for group in okta_qs_group_response:
                group_url = group['_links']['group']['href']
                group_info = (requests.get(group_url, headers=headers)).json()
                okta_qs_app_group_list.append(group_info['profile']['name'])
        
        def check_qs_user_exist(user_name):
                try:
                        qs_user_response = qs_client.describe_user(
                                        UserName=user_name,
                                        AwsAccountId=account_id,
                                        Namespace=default_namespace
                                        )
                        return[qs_user_response['User'].get('UserName'),qs_user_response['User'].get('Email'),qs_user_response['User'].get('Role')]
                except:
                        return("None")
        
        def register_qs_user(user_name,user_email,user_type,federated_role):
                qs_role_arn = 'arn:aws:iam::'+account_id+':role/'+federated_role

                qs_register_user_response = qs_client.register_user(
                                    IdentityType='IAM',
                                    Email=user_email,
                                    UserRole=user_type.upper(),
                                    AwsAccountId=account_id,
                                    Namespace=default_namespace,
                                    IamArn=qs_role_arn,
                                    SessionName=user_name
                                    )

        def update_user_role(user_name,user_email,user_role):
                response = qs_client.update_user(
                    UserName=user_name,
                    AwsAccountId=account_id,
                    Namespace=default_namespace,
                    Email=user_email,
                    Role=user_role.upper(),
                    )

        def list_qs_user_groups(user_name,user_email):
                response = qs_client.list_user_groups(
                UserName=user_name,
                AwsAccountId=account_id,
                Namespace=default_namespace,
                )
                r = []
                if len(response['GroupList'])>0:
                        for i in range(0,len(response['GroupList'])):
                                r.append(response['GroupList'][i].get('GroupName'))
                        return(r)
                else:
                        pass
    
        def delete_group_membership(user_name,group_name):
                response = qs_client.delete_group_membership(
                        MemberName=user_name,
                        GroupName=group_name,
                        AwsAccountId=account_id,
                        Namespace=default_namespace
                )
                
        def create_group_membership(user_name,group_name):
                response = qs_client.create_group_membership(
                        MemberName=user_name,
                        GroupName=group_name,
                        AwsAccountId=account_id,
                        Namespace=default_namespace
                        )

        # get the quicksight role from the role and policies attached
        def get_quicksight_role(role_name):

                quicksight_user_role_list = []
                #get AWS or Customer Managed IAM polices attached to federated role 
                get_iam_policies_attached = iam_client.list_attached_role_policies(
                                        RoleName=role_name
                                        )
                attached_polices = get_iam_policies_attached['AttachedPolicies']

                for i in range(0,len(attached_polices)):
                        policy_arn = attached_polices[i]['PolicyArn']

                        get_policy_version = iam_client.get_policy(
                                        PolicyArn=policy_arn
                                        )
                        default_version_id = get_policy_version['Policy']['DefaultVersionId']

                        get_policy_description = iam_client.get_policy_version(
                                        PolicyArn=policy_arn,
                                        VersionId=default_version_id  
                                        )
                        if get_policy_description['PolicyVersion']['Document']['Statement'][0]['Effect'] == 'Allow':
                                create_action = get_policy_description['PolicyVersion']['Document']['Statement'][0]['Action']
                        
                        if type(create_action) is str:
                                quicksight_user_role_list.append(create_action)
                        else:
                                quicksight_user_role_list.extend(create_action)    

                #get list of In-Line IAM polices attached to federated role 
                get_iam_policies_in_line = iam_client.list_role_policies(
                                        RoleName=role_name
                                        )

                in_line_policies = get_iam_policies_in_line['PolicyNames']

                for i in range(0,len(in_line_policies)):
                        get_in_line_policy_description = iam_client.get_role_policy(
                                        RoleName=role_name,
                                        PolicyName = in_line_policies[i]
                                        )
                        create_action = get_in_line_policy_description['PolicyDocument']['Statement'][0]['Action']

                        if type(create_action) is str:
                                quicksight_user_role_list.append(create_action)
                        else:
                                quicksight_user_role_list.extend(create_action)


                #set user role to None, to map it for IAM roles not related to QuickSight
                quicksight_user_role = 'NOT-QUICKSIGHT-IAM-ROLE'

                if 'quicksight:CreateReader' in quicksight_user_role_list:
                        quicksight_user_role = 'READER'

                if 'quicksight:CreateUser' in quicksight_user_role_list:
                        quicksight_user_role = 'AUTHOR'

                if 'quicksight:CreateAdmin' in quicksight_user_role_list:
                        quicksight_user_role = 'ADMIN'
       
                quicksight_iam_role_dict[role_name] = quicksight_user_role

        # Main Block
        for user in  okta_qs_users_response:

                #QS User Name Formatting 
                okta_user_id = user['id']
                # Changed logic to check multiple users with every saml role
                okta_username = user['credentials']['userName']
                #New Okta User - Only user name part from Okta is needed for new user registration
                #QS User Email
                okta_user_email = user['profile']['email']
                #QS User Type 
                #QS User IAM role mapping in Okta
                okta_user_saml_roles = user['profile']['samlRoles']
                
                #QS User groups in Okta
                qs_user_group_list = []
                okta_user_group_list = []
                user_group_url = os.environ['okta_domain']+"/api/v1/users/{0}/groups".format(okta_user_id)
                user_group_reponse = (requests.get(user_group_url, headers=headers)).json()

                for user_group_info in user_group_reponse:
                        user_group = user_group_info['profile']['name']
                        if user_group in okta_qs_app_group_list:
                                okta_user_group_list.append('Okta-'+user_group)

                for role in okta_user_saml_roles:
                        okta_user_name = role+'/'+okta_username
                        qs_user_info=check_qs_user_exist(okta_user_name)
                        okta_user_type = quicksight_iam_role_dict.get(role)
                        if okta_user_type == None:
                                get_quicksight_role(role)
                                okta_user_type = quicksight_iam_role_dict.get(role)

                        if okta_user_type != 'NOT-QUICKSIGHT-IAM-ROLE':        
                                # Register User if not exist 
                                if qs_user_info == "None":
                                        register_qs_user(okta_username,okta_user_email,okta_user_type,role)
                                        # Redo user check after registration to update the group membership 
                                        qs_user_info=check_qs_user_exist(okta_user_name)
                                
                                #Check UserName 
                                if (okta_user_name == qs_user_info[0] and okta_user_email == qs_user_info[1]):
                                        #Check Role
                                        if okta_user_type.upper() == qs_user_info[2].upper():
                                                pass 
                                        else:
                                                try:
                                                        update_user_role(okta_user_name,okta_user_email,okta_user_type)
                                                except Exception:
                                                        print("You cannot downgrade a user role")
                                                
                                        #List QS User group Memebership
                                        qs_user_group_list = list_qs_user_groups(okta_user_name,okta_user_email)
                        
                        # Delete Group Membership
                        if qs_user_group_list is not None:
                                for i in range(0,len(qs_user_group_list)):
                                        if qs_user_group_list[i] in okta_user_group_list:
                                                pass
                                        else:
                                                delete_group_membership(okta_user_name,qs_user_group_list[i])
                                                
                        # Create Group Membership        
                        if len(okta_user_group_list)>0:
                                for i in range(0,len(okta_user_group_list)):
                                        if okta_user_group_list[i] == 'Everyone':
                                                pass
                                        elif (len(okta_user_group_list[i])>0 and qs_user_group_list is None):
                                                create_group_membership(okta_user_name,str(okta_user_group_list[i]))
                                        elif okta_user_group_list[i] in qs_user_group_list:
                                                pass
                                        else:
                                                create_group_membership(okta_user_name,str(okta_user_group_list[i]))