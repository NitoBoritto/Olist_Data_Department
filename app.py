import os
from openai import OpenAI
import os
token = os.environ.get("HuggingFace_HUB_TOKEN")

client = OpenAI(
    base_url="https://router.huggingface.co/v1",
    api_key=token
)

completion = client.chat.completions.create(
    model="Qwen/Qwen2.5-7B-Instruct:featherless-ai",
    messages=[
        {
            "role": "user",
            "content": "Explain the Olist ecommerce dataset"
        }
    ],
)

print(completion.choices[0].message.content)