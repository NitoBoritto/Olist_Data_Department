import os
from openai import OpenAI

client = OpenAI(
    base_url="https://router.huggingface.co/v1",
    api_key="REMOVED"
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