"""
Main pipeline orchestration script for Olist ML project.

Runs the sentiment analysis pipeline end-to-end.
Handles data extraction, preprocessing, tuning, training, and evaluation,
with MLflow tracking and model artifact management.
"""

import argparse
import sys
from pathlib import Path
import mlflow
import joblib
import json
from datetime import datetime
import traceback

# Add project root to path
project_root = Path(__file__).parent.parent
if str(project_root) not in sys.path:
    sys.path.insert(0, str(project_root))


def setup_mlflow(experiment_name: str) -> None:
    """Setup MLflow experiment tracking."""
    mlflow.set_experiment(experiment_name)
    print(f"[MLFLOW] Set experiment: {experiment_name}")


def run_sentiment_pipeline(
    input_csv: str = None,
    n_trials: int = 50,
    experiment_name: str = "Olist-Sentiment-Analysis",
) -> dict:
    """
    Run complete sentiment analysis pipeline.
    
    Args:
        input_csv: Optional local CSV file to use instead of Azure SQL
        n_trials: Number of Optuna trials for hyperparameter tuning
        experiment_name: MLflow experiment name
    
    Returns:
        Dictionary with final metrics and model path
    """
    print("\n" + "="*70)
    print("PIPELINE 1: SENTIMENT ANALYSIS")
    print("="*70)
    
    setup_mlflow(experiment_name)

    from sklearn.model_selection import train_test_split
    from src.data.extract import extract_sentiment_data
    from src.data.preprocess import preprocess_sentiment_data, encode_sentiment_labels
    from src.models.tune import tune_sentiment_classifier
    from src.models.train import train_sentiment_model
    from src.models.evaluate import evaluate_sentiment_model
    
    with mlflow.start_run():
        try:
            # Extract
            print("\n[1/6] EXTRACTING DATA...")
            df_raw = extract_sentiment_data(input_csv=input_csv)
            
            # Preprocess
            print("\n[2/6] PREPROCESSING DATA...")
            df_clean = preprocess_sentiment_data(df_raw)
            
            # Encode sentiment labels
            df_clean, label_mapping = encode_sentiment_labels(df_clean)
            mlflow.log_dict(label_mapping, "sentiment_label_mapping.json")
            
            # Split data
            print("\n[3/6] SPLITTING DATA...")
            X_train, X_test, y_train, y_test = train_test_split(
                df_clean["review_text"],
                df_clean["sentiment_encoded"],
                test_size=0.2,
                stratify=df_clean["sentiment_encoded"],
                random_state=30,
            )
            print(f"  Train: {len(X_train)}, Test: {len(X_test)}")
            
            # Tune
            print("\n[4/6] TUNING HYPERPARAMETERS...")
            best_params = tune_sentiment_classifier(X_train, y_train, n_trials=n_trials)
            
            # Log parameters
            for key, value in best_params.items():
                mlflow.log_param(key, value)
            
            # Train
            print("\n[5/6] TRAINING MODEL...")
            model, model_label_mapping = train_sentiment_model(X_train, y_train, best_params)
            mlflow.log_dict(model_label_mapping, "model_label_mapping.json")
            
            # Evaluate
            print("\n[6/6] EVALUATING MODEL...")
            metrics = evaluate_sentiment_model(model, X_test, y_test, model_label_mapping)
            
            # Save model locally
            model_dir = project_root / "src" / "serving" / "models" / "sentiment_model"
            model_dir.mkdir(parents=True, exist_ok=True)
            joblib.dump(model, model_dir / "sentiment_pipeline.pkl")
            
            # Save label mapping for inference
            with open(model_dir / "label_mapping.json", "w") as f:
                json.dump(model_label_mapping, f)
            
            print(f"\n[MODEL] Saved to {model_dir}/sentiment_pipeline.pkl")
            
            # Log to MLflow
            mlflow.sklearn.log_model(model, artifact_path="sentiment_model")
            
            print("\n[SUCCESS] Sentiment pipeline completed!")
            return {
                "pipeline": "sentiment",
                "metrics": metrics,
                "model_path": str(model_dir / "sentiment_pipeline.pkl"),
            }
        
        except FileNotFoundError as e:
            print(f"\n[ERROR] {e}")
            mlflow.log_param("status", "failed")
            raise
        except Exception as e:
            print(f"\n[ERROR] Pipeline failed: {e}")
            print(traceback.format_exc())
            mlflow.log_param("status", "failed")
            raise


def print_summary(results: list) -> None:
    """Print final summary table."""
    print("\n" + "="*70)
    print("PIPELINE SUMMARY")
    print("="*70)
    
    for result in results:
        pipeline_name = result["pipeline"].upper()
        metrics = result.get("metrics", {})
        
        print(f"\n{pipeline_name}:")
        print(f"  Model path: {result.get('model_path') or result.get('classifier_path')}")
        
        if metrics:
            print("  Key metrics:")
            for key in sorted(metrics.keys())[:5]:  # Show first 5 metrics
                value = metrics[key]
                if isinstance(value, float):
                    print(f"    - {key}: {value:.4f}")
                else:
                    print(f"    - {key}: {value}")


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Olist ML Pipeline Orchestrator",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    
    parser.add_argument(
        "--pipeline",
        type=str,
        default="sentiment",
        choices=["sentiment"],
        help="Pipeline to run (only sentiment is supported)",
    )
    
    parser.add_argument(
        "--input",
        type=str,
        default=None,
        help="Local CSV file to use instead of Azure SQL (for development)",
    )
    
    parser.add_argument(
        "--experiment",
        type=str,
        default=None,
        help="MLflow experiment name override",
    )
    
    parser.add_argument(
        "--n_trials",
        type=int,
        default=50,
        help="Number of Optuna trials for sentiment tuning (default: 50)",
    )
    
    args = parser.parse_args()
    
    print("\n" + "="*70)
    print("OLIST ML PIPELINE ORCHESTRATOR")
    print(f"Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("="*70)
    
    results = []
    
    try:
        result = run_sentiment_pipeline(
            input_csv=args.input,
            n_trials=args.n_trials,
            experiment_name=args.experiment or "Olist-Sentiment-Analysis",
        )
        results.append(result)
        
        # Print summary
        print_summary(results)
        
        print("\n[COMPLETED] All pipelines finished successfully!")
        print(f"Ended: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print("="*70 + "\n")
    
    except Exception as e:
        print("\n[FATAL] Pipeline execution failed!")
        print(f"Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
