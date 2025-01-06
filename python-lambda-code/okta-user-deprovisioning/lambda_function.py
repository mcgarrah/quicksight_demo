import botocore
import requests
import botocore.session
import os
import json


#Okta Config
#Get All users from Okta for quickisght app only: 
qs_app_id_on_okta = os.environ['okta_quicksight_app_id']
#Okta url 
okta_domain = os.environ['okta_domain']
all_user_url=okta_domain+'/api/v1/apps/'+qs_app_id_on_okta+"/users?"
        
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
    #qs_role_arn = 'arn:aws:iam::'+os.environ['aws_account_id']+':role/'+os.environ['okta_federated_role']
    new_owner_user = os.environ['transfer_assets_to']

    # load from environ variable
    quicksight_reader_role = os.environ['quicksight_reader_IAM_role']
    quicksight_author_role = os.environ['quicksight_author_IAM_role']
    quicksight_admin_role = os.environ['quicksight_admin_IAM_role']

    quicksight_role_list =[quicksight_reader_role,quicksight_author_role,quicksight_admin_role]

    response = requests.get(all_user_url, headers=headers)
    all_users_response = response.json()
    okta_user_list = []
    
    #get all Quicksight app user list from Okta
    for okta_user in all_users_response:
        for user_role in okta_user['profile']['samlRoles']:
         okta_user_list.append(user_role+'/'+okta_user['credentials']['userName'])
        
    

    #Get All quicksight Users 
    qs_user_list = [] 

    qs_users= qs_client.list_users(
                                            AwsAccountId=account_id,
                                            Namespace=default_namespace
                                            )
    for qs_user in qs_users['UserList']:
        if qs_user['IdentityType'] == 'IAM' and (str(qs_user['UserName']).split("/")[0] in quicksight_role_list):
            qs_user_list.append(qs_user['UserName'])
            
    #Compare Okta and Quicksight user list and get list to deprovision users        
    qs_delete_user_list = (list(set(qs_user_list) - set(okta_user_list)))

    #print(qs_delete_user_list)
                                            
    # List of Default Assets addded to quicksight users. This is to excluded from asset search
    qs_sample_analysis_list = ['Web and Social Media Analytics analysis','People Overview analysis','Business Review analysis','Sales Pipeline analysis']
    qs_sample_dataset_list = ['Web and Social Media Analytics','People Overview', 'Business Review', 'Sales Pipeline']
    qs_sample_datasource_list = ['Web and Social Media Analytics', 'People Overview', 'Business Review', 'Sales Pipeline']
    qs_default_theme_list = ['CLASSIC','MIDNIGHT','SEASIDE','RAINIER']
        
    # Check if user exist
    def check_qs_user(user_name):
        qs_user_response = qs_client.describe_user(
                                UserName=user_name,
                                AwsAccountId=account_id,
                                Namespace=default_namespace
                                )
        return[qs_user_response['User'].get('UserName'),qs_user_response['User'].get('Email'),qs_user_response['User'].get('Role'),qs_user_response['User'].get('Arn')]
        
     #Get the list of analysis permissions for the user
    def get_analyses_permissions(user_principal_arn):
        all_analyses = []
        response = qs_client.list_analyses(
                        AwsAccountId=account_id
                    )
                        
        for i in range(0,len(response['AnalysisSummaryList'])):
            analysis_name = response['AnalysisSummaryList'][i]['Name']
            analysis_id = response['AnalysisSummaryList'][i]['AnalysisId']
            if analysis_name not in qs_sample_analysis_list:
                analysis_permission_response = qs_client.describe_analysis_permissions(
                                                    AwsAccountId=account_id,
                                                    AnalysisId=analysis_id
                                                    )
                for x in range(0,len(analysis_permission_response['Permissions'])):
                    if (user_principal_arn == analysis_permission_response['Permissions'][x]['Principal']):
                        all_analyses.append(analysis_id)
                else:
                    pass
        
            else:
                pass

        return(all_analyses)
    
    def get_dashboard_permissions(user_principal_arn):
        all_dashboards = []
        response = qs_client.list_dashboards(
                    AwsAccountId=account_id
                        )
        for i in range(0,len(response['DashboardSummaryList'])):
            dashboard_id = response['DashboardSummaryList'][i]['DashboardId']
            dashboard_permission_response = qs_client.describe_dashboard_permissions(
                                                   AwsAccountId=account_id,
                                                   DashboardId=dashboard_id
                                                 )
            for x in range(0,len(dashboard_permission_response['Permissions'])):
                if (user_principal_arn == dashboard_permission_response['Permissions'][x]['Principal']):
                    all_dashboards.append(dashboard_id)
                else:
                    pass

        return(all_dashboards)
            
        
    def get_dataset_permissions(user_principal_arn):
        all_datasets = []
        response = qs_client.list_data_sets(
                        AwsAccountId=account_id
                    )
        for i in range(0,len(response['DataSetSummaries'])):
            dataset_name = response['DataSetSummaries'][i]['Name']
            dataset_id = response['DataSetSummaries'][i]['DataSetId']
            if dataset_name not in qs_sample_dataset_list:
                dataset_permission_response = qs_client.describe_data_set_permissions(
                                                       AwsAccountId=account_id,
                                                       DataSetId=dataset_id
                                                     )
                for x in range(0,len(dataset_permission_response['Permissions'])):
                    if (user_principal_arn == dataset_permission_response['Permissions'][x]['Principal']):
                        all_datasets.append(dataset_id)
                    else:
                        pass

        return(all_datasets)   
            
            
            
    def get_datasource_permissions(user_principal_arn):
        all_datasources = []
        response = qs_client.list_data_sources(
                        AwsAccountId=account_id
                    )
        
        for i in range(0,len(response['DataSources'])):
            datasource_name = response['DataSources'][i]['Name']
            datasource_id = response['DataSources'][i]['DataSourceId']
            if datasource_name not in qs_sample_datasource_list:
                datasource_permission_response = qs_client.describe_data_source_permissions(
                                                            AwsAccountId=account_id,
                                                            DataSourceId=datasource_id
                                                          )
                for x in range(0,len(datasource_permission_response['Permissions'])):
                    if (user_principal_arn == datasource_permission_response['Permissions'][x]['Principal']):
                        all_datasources.append(datasource_id)
                    else:
                        pass
    
        return(all_datasources)    
            
            
    def get_theme_permissions(user_principal_arn):
        all_themes = []
        response = qs_client.list_themes(
                    AwsAccountId=account_id
                    )

        for i in range(0,len(response['ThemeSummaryList'])):
            theme_id = response['ThemeSummaryList'][i]['ThemeId']
            if theme_id not in qs_default_theme_list:
                theme_permission_response = qs_client.describe_theme_permissions(
                                                    AwsAccountId=account_id,
                                                    ThemeId=theme_id
                                                    )
                for x in range(0,len(theme_permission_response['Permissions'])):
                    if (user_principal_arn == theme_permission_response['Permissions'][x]['Principal']):
                        all_themes.append(theme_id)
                    else:
                        pass
    
        return(all_themes)    
            
            
    def check_new_owner_user_role(user_principal_arn,new_owner_user):

        response = qs_client.describe_user(
                        UserName=new_owner_user,
                        AwsAccountId=account_id,
                        Namespace=default_namespace
                    )
        new_owner_user_arn = response['User'].get('Arn')
        new_owner_role = response['User'].get('Role')

        if user_principal_arn != new_owner_user_arn:
            if new_owner_role in ['ADMIN','AUTHOR']:   
                return(new_owner_user_arn)
            else:
                return(None)
        else:
                return(None)

    def move_analysis_permissions_to_admin_user(user_principal_arn,admin_user_principal_arn,all_analyses_list):
        for i in range(0,len(all_analyses_list)):
            response = qs_client.update_analysis_permissions(
                            AwsAccountId=account_id,
                            AnalysisId=all_analyses_list[i],
                            GrantPermissions=[
                                {
                                    'Principal': admin_user_principal_arn,
                                    'Actions': ['quicksight:RestoreAnalysis', 
                                                'quicksight:UpdateAnalysisPermissions',
                                                'quicksight:DeleteAnalysis',
                                                'quicksight:QueryAnalysis',
                                                'quicksight:DescribeAnalysisPermissions',
                                                'quicksight:DescribeAnalysis',
                                                'quicksight:UpdateAnalysis']
                                },
                            ],
                            RevokePermissions=[
                                {
                                    'Principal': user_principal_arn,
                                    'Actions': ['quicksight:RestoreAnalysis', 
                                                'quicksight:UpdateAnalysisPermissions',
                                                'quicksight:DeleteAnalysis',
                                                'quicksight:QueryAnalysis',
                                                'quicksight:DescribeAnalysisPermissions',
                                                'quicksight:DescribeAnalysis',
                                                'quicksight:UpdateAnalysis']
                                },
                            ]
                        )
            
    def move_dashboard_permissions_to_admin_user(user_principal_arn,admin_user_principal_arn,all_dashboard_list):
        for i in range(0,len(all_dashboard_list)):
            response = qs_client.update_dashboard_permissions(
                                AwsAccountId=account_id,
                                DashboardId=all_dashboard_list[i],
                                GrantPermissions=[
                                    {
                                        'Principal': admin_user_principal_arn,
                                        'Actions': ['quicksight:DescribeDashboard',
                                                    'quicksight:ListDashboardVersions',
                                                    'quicksight:UpdateDashboardPermissions',
                                                    'quicksight:QueryDashboard',
                                                    'quicksight:UpdateDashboard',
                                                    'quicksight:DeleteDashboard',
                                                    'quicksight:DescribeDashboardPermissions',
                                                    'quicksight:UpdateDashboardPublishedVersion']
                                    },
                                ],
                                RevokePermissions=[
                                    {
                                        'Principal': user_principal_arn,
                                        'Actions': ['quicksight:DescribeDashboard',
                                                    'quicksight:ListDashboardVersions',
                                                    'quicksight:UpdateDashboardPermissions',
                                                    'quicksight:QueryDashboard',
                                                    'quicksight:UpdateDashboard',
                                                    'quicksight:DeleteDashboard',
                                                    'quicksight:DescribeDashboardPermissions',
                                                    'quicksight:UpdateDashboardPublishedVersion']
                                    },
                                ]
                            )    
            
            
    def move_dataset_permissions_to_admin_user(user_principal_arn,admin_user_principal_arn,all_dataset_list):
        print('admin-user is: ' + admin_user_principal_arn)
        for i in all_dataset_list:
            response = qs_client.update_data_set_permissions(
                            AwsAccountId=account_id,
                            DataSetId=i,
                            GrantPermissions=[
                                {
                                    'Principal':admin_user_principal_arn,
                                    'Actions': ["quicksight:DeleteDataSet",
                                                "quicksight:UpdateDataSetPermissions",
                                                "quicksight:PutDataSetRefreshProperties",
                                                "quicksight:CreateRefreshSchedule",
                                                "quicksight:CancelIngestion",
                                                "quicksight:UpdateRefreshSchedule",
                                                "quicksight:ListRefreshSchedules",
                                                "quicksight:DeleteRefreshSchedule",
                                                "quicksight:DescribeDataSetRefreshProperties",
                                                "quicksight:DescribeDataSet",
                                                "quicksight:CreateIngestion",
                                                "quicksight:PassDataSet",
                                                "quicksight:DescribeRefreshSchedule",
                                                "quicksight:ListIngestions",
                                                "quicksight:UpdateDataSet",
                                                "quicksight:DescribeDataSetPermissions",
                                                "quicksight:DeleteDataSetRefreshProperties",
                                                "quicksight:DescribeIngestion"]
                                }
                            ],
                            RevokePermissions=[
                                {
                                    'Principal': user_principal_arn,
                                    'Actions': ["quicksight:DeleteDataSet",
                                                "quicksight:UpdateDataSetPermissions",
                                                "quicksight:PutDataSetRefreshProperties",
                                                "quicksight:CreateRefreshSchedule",
                                                "quicksight:CancelIngestion",
                                                "quicksight:UpdateRefreshSchedule",
                                                "quicksight:ListRefreshSchedules",
                                                "quicksight:DeleteRefreshSchedule",
                                                "quicksight:DescribeDataSetRefreshProperties",
                                                "quicksight:DescribeDataSet",
                                                "quicksight:CreateIngestion",
                                                "quicksight:PassDataSet",
                                                "quicksight:DescribeRefreshSchedule",
                                                "quicksight:ListIngestions",
                                                "quicksight:UpdateDataSet",
                                                "quicksight:DescribeDataSetPermissions",
                                                "quicksight:DeleteDataSetRefreshProperties",
                                                "quicksight:DescribeIngestion"]
                                }
                            ]
                        )
            
            
    def move_datasource_permissions_to_admin_user(user_principal_arn,admin_user_principal_arn,all_datasource_list):
        for i in range(0,len(all_datasource_list)):
            response = qs_client.update_data_source_permissions(
                            AwsAccountId=account_id,
                            DataSourceId=all_datasource_list[i],
                            GrantPermissions=[
                                {
                                    'Principal': admin_user_principal_arn,
                                    'Actions': ['quicksight:UpdateDataSourcePermissions',
                                                'quicksight:DescribeDataSource',
                                                'quicksight:DescribeDataSourcePermissions',
                                                'quicksight:PassDataSource',
                                                'quicksight:UpdateDataSource',
                                                'quicksight:DeleteDataSource']
                                },
                            ],
                            RevokePermissions=[
                                {
                                    'Principal': user_principal_arn,
                                    'Actions': ['quicksight:UpdateDataSourcePermissions',
                                                'quicksight:DescribeDataSource',
                                                'quicksight:DescribeDataSourcePermissions',
                                                'quicksight:PassDataSource',
                                                'quicksight:UpdateDataSource',
                                                'quicksight:DeleteDataSource']
                                },
                            ]
                        ) 
            
    def move_theme_permissions_to_admin_user(user_principal_arn,admin_user_principal_arn,all_themes_list):
        for i in range(0,len(all_themes_list)):
            response = qs_client.update_theme_permissions(
                            AwsAccountId=account_id,
                            ThemeId=all_themes_list[i],
                            GrantPermissions=[
                                {
                                    'Principal': admin_user_principal_arn,
                                    'Actions': ['quicksight:ListThemeVersions',
                                                'quicksight:UpdateThemeAlias',
                                                'quicksight:UpdateThemePermissions',
                                                'quicksight:DescribeThemeAlias',
                                                'quicksight:DeleteThemeAlias',
                                                'quicksight:DeleteTheme',
                                                'quicksight:ListThemeAliases',
                                                'quicksight:DescribeTheme',
                                                'quicksight:CreateThemeAlias',
                                                'quicksight:UpdateTheme',
                                                'quicksight:DescribeThemePermissions']
                                },
                            ],
                            RevokePermissions=[
                                {
                                    'Principal': user_principal_arn,
                                    'Actions': ['quicksight:ListThemeVersions',
                                                'quicksight:UpdateThemeAlias',
                                                'quicksight:UpdateThemePermissions',
                                                'quicksight:DescribeThemeAlias',
                                                'quicksight:DeleteThemeAlias',
                                                'quicksight:DeleteTheme',
                                                'quicksight:ListThemeAliases',
                                                'quicksight:DescribeTheme',
                                                'quicksight:CreateThemeAlias',
                                                'quicksight:UpdateTheme',
                                                'quicksight:DescribeThemePermissions']
                                },
                            ]
                        )
            
                
    def qs_delete_user(user_name):
        response = qs_client.delete_user(
                            UserName=user_name,
                            AwsAccountId=account_id,
                            Namespace=default_namespace
                                )
    
    #'''            
    # Main block
    for user in qs_delete_user_list:
        qs_user_info=check_qs_user(user)
        user_arn = qs_user_info[3]
        if qs_user_info[0] == "READER":
            qs_delete_user(user)
                    
        elif qs_user_info[0] == None:
            pass
                    
        else:
            new_owner_user_arn = check_new_owner_user_role(user_arn,new_owner_user)
            if new_owner_user_arn != None:
                all_analyses_list = get_analyses_permissions(user_arn)
                all_dashboard_list = get_dashboard_permissions(user_arn)
                all_dataset_list = get_dataset_permissions(user_arn)
                all_datasource_list = get_datasource_permissions(user_arn)
                all_themes_list = get_theme_permissions(user_arn)            
                move_analysis_permissions_to_admin_user(user_arn,new_owner_user_arn,all_analyses_list)
                move_dashboard_permissions_to_admin_user(user_arn,new_owner_user_arn,all_dashboard_list)
                move_dataset_permissions_to_admin_user(user_arn,new_owner_user_arn,all_dataset_list)
                move_datasource_permissions_to_admin_user(user_arn,new_owner_user_arn,all_datasource_list)
                move_theme_permissions_to_admin_user(user_arn,new_owner_user_arn,all_themes_list)
                qs_delete_user(user)