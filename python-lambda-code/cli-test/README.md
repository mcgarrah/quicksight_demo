# Testing CLI

Setup the `.venv` environment for Python3 to run the example and install the libraries.

``` console
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

The dotEnv file example is called `env-example` and needs to renamed to `.env` then replace the placeholder values.

``` ini
okta_domain=https://mcgarrah.okta.com
okta_api_token=00RYCPqYQs4gVkqTlWqe0Xx1tof3cHuySQmAdSuJYF
okta_quicksight_app_id=0bal26or5eCQPHrOq2x4
```

Run the code.

``` shell
python main.py
```

Proof the Okta API is working with the API Token and URL provided. Less insane than trying to debug in Lambda.
