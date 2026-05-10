import joblib
from pathlib import Path
p = Path('src/serving/models/sentiment_model/sentiment_pipeline.pkl')
print('exists', p.exists())
if p.exists():
    mdl = joblib.load(p)
    print('model type:', type(mdl))
    try:
        pre = mdl.named_steps.get('preprocessor')
        print('preprocessor type', type(pre))
        if hasattr(pre, 'transformers'):
            for name, trans, cols in pre.transformers:
                print('transformer:', name, 'cols:', cols, 'type:', type(trans))
                if hasattr(trans, 'categories_'):
                    try:
                        print('  handle_unknown:', getattr(trans, 'handle_unknown', None))
                        print('  categories (first 3 each):', [list(c)[:3] for c in trans.categories_])
                    except Exception as e:
                        print('  could not inspect categories:', e)
    except Exception as e:
        print('inspect error', e)
else:
    print('model file not found')
