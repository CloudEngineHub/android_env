# coding=utf-8
# Copyright 2026 DeepMind Technologies Limited.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Hermetic Bazel launcher for grpc_tools.protoc with built-in well-known protos."""

import os
import sys
from grpc_tools import protoc


def main():
  args = sys.argv[1:]
  # Automatically add the embedded grpc_tools/_proto directory for
  # google/protobuf/*.proto files.
  grpc_tools_dir = os.path.dirname(protoc.__file__)
  proto_include = os.path.join(grpc_tools_dir, '_proto')
  if os.path.exists(proto_include):
    args = [f'-I{proto_include}'] + args

  return protoc.main([sys.argv[0]] + args)


if __name__ == '__main__':
  sys.exit(main())
