import os

import boto3

model = os.environ["PARSER_MODEL"]
brt = boto3.client("bedrock-runtime", region_name="us-east-1")
resp = brt.converse(
    modelId=model,
    messages=[{"role": "user", "content": [{"text": "In one sentence: what is an ISO week?"}]}],
    inferenceConfig={"maxTokens": 200},
)
print(resp["output"]["message"]["content"][0]["text"])
print(resp["stopReason"], resp["usage"])
