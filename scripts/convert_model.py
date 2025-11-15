"""
Convert MobileFaceNet ONNX model to Core ML format.

Prerequisites:
    pip install coremltools onnx

Usage:
    python scripts/convert_model.py --input models/mobilefacenet.onnx --output models/MobileFaceNet.mlmodel
"""
import argparse
import coremltools as ct
import numpy as np


def convert_mobilefacenet(input_path: str, output_path: str):
    """Convert MobileFaceNet from ONNX to Core ML .mlmodel format."""
    model = ct.converters.onnx.convert(
        model=input_path,
        minimum_ios_deployment_target="15.0",
    )

    model.input_description["input"] = "Aligned face image (112x112 RGB)"
    model.output_description["embedding"] = "512-dimensional face embedding vector"
    model.author = "Mentra"
    model.short_description = (
        "MobileFaceNet face recognition model. "
        "Produces 512-dim embeddings from aligned 112x112 face crops."
    )
    model.version = "1.0"

    model.save(output_path)
    print(f"Model saved to {output_path}")
    print(f"Input: {model.input_description}")
    print(f"Output: {model.output_description}")

    spec = model.get_spec()
    output_shape = spec.description.output[0].type.multiArrayType.shape
    assert list(output_shape) == [1, 512], f"Expected [1, 512], got {list(output_shape)}"
    print("Output shape verified: [1, 512]")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Convert MobileFaceNet ONNX to Core ML")
    parser.add_argument("--input", required=True, help="Path to ONNX model")
    parser.add_argument("--output", required=True, help="Output .mlmodel path")
    args = parser.parse_args()
    convert_mobilefacenet(args.input, args.output)
