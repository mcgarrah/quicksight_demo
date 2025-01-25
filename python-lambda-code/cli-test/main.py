import requests
import os
from dotenv import load_dotenv
from pprint import pprint

def main():

  print("Starting...")

  load_dotenv()

  #Okta Config
  #Get All users from Okta for quickisght app only: 
  qs_app_id_on_okta = os.environ['okta_quicksight_app_id']
  okta_domain = os.environ['okta_domain']
  okta_api_token = os.environ['okta_api_token']

  pprint(qs_app_id_on_okta)
  pprint(okta_domain)
  pprint(okta_api_token)

  # Build Okta URL to get all Quicksight users
  all_users_url=okta_domain+'/api/v1/apps/'+qs_app_id_on_okta+"/users?"

  pprint (all_users_url)

  #Build Okta URL to get all Quicksight app groups mapped in Okta
  okta_qs_app_group_url=okta_domain+"/api/v1/apps/"+qs_app_id_on_okta+"/groups"

  pprint (okta_qs_app_group_url)

  # TODO: SSWS authentication review
  # https://developer.okta.com/docs/reference/rest/#set-up-okta-for-api-access
  #
  
  #Okta API Request Header
  headers = {
          'accept': 'application/json',
          'authorization' : 'SSWS '+ okta_api_token,
          'content-type': 'application/json'
          }

  okta_qs_app_group_list=[]

  #Okta Response
  okta_qs_group_response = (requests.get(okta_qs_app_group_url, headers=headers)).json()
  pprint(okta_qs_group_response)

  okta_qs_users_response = (requests.get(all_users_url, headers=headers)).json()
  pprint(okta_qs_users_response)

  for group in okta_qs_group_response:
    group_url = group['_links']['group']['href']
    group_info = (requests.get(group_url, headers=headers)).json()
    okta_qs_app_group_list.append(group_info['profile']['name'])

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
    user_group_url = okta_domain+"/api/v1/users/{0}/groups".format(okta_user_id)
    user_group_reponse = (requests.get(user_group_url, headers=headers)).json()

    for user_group_info in user_group_reponse:
      user_group = user_group_info['profile']['name']
      if user_group in okta_qs_app_group_list:
        okta_user_group_list.append('Okta-'+user_group)

if __name__ == "__main__":
    main()