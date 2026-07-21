"""Pure Python Proto and gRPC generation macros using prebuilt wheel binaries.

RATIONALE & PERFORMANCE CONSIDERATIONS:
----------------------------------------
These macros invoke `protoc_runner` (which wraps `grpc_tools.protoc` from
`@pip//grpcio_tools`) via a lightweight Bazel `genrule` instead of relying on
`rules_proto_grpc_python`.

Why this is done:
1. `rules_proto_grpc_python` pulls in `@grpc~` C++ source dependencies (`cygrpc.so`,
   `abseil-cpp`, and the `protobuf` C++ runtime), forcing Bazel to compile C++ source
   code on cold checkouts.
2. Compiling `@grpc~` C++ targets takes ~17 minutes on cold checkouts.
3. By using the hermetic `//:protoc_runner` tool (`@pip//grpcio_tools`), proto and gRPC
   code generation completes in under 1 second without compiling any C++ code, reducing
   total cold checkout build times from ~17 minutes to ~1 minute.
"""

load("@rules_python//python:defs.bzl", "py_library")

def _dedup(seq):
    seen = {}
    return [x for x in seq if not (x in seen or seen.update({x: 1}))]

def py_proto_library(name, srcs, proto_srcs = [], deps = [], visibility = ["//visibility:public"]):
    """Generates _pb2.py message files for srcs using hermetic protoc_runner.

    Avoids compiling C++ protobuf source dependencies to keep cold build times fast.

    Args:
      name: Target name for the generated py_library.
      srcs: List of primary .proto files to generate _pb2.py for.
      proto_srcs: Additional .proto files needed in the Bazel sandbox for imports.
      deps: Additional Python library dependencies.
      visibility: Visibility specifier for the generated py_library.
    """
    outs = [s[:-6] + "_pb2.py" if s.endswith(".proto") else s + "_pb2.py" for s in srcs]
    pkg_parts = native.package_name().split("/")
    depth = "../" * len(pkg_parts)
    root_import = "/".join([".."] * len(pkg_parts))
    gen_name = name + "_gen"

    all_srcs = _dedup(srcs + proto_srcs)

    native.genrule(
        name = gen_name,
        srcs = all_srcs,
        outs = outs,
        cmd = "$(location //:protoc_runner) -I. --python_out=$(RULEDIR)/" + depth + " " + " ".join(["$(location " + s + ")" for s in srcs]),
        tools = ["//:protoc_runner"],
    )

    py_library(
        name = name,
        srcs = [":" + gen_name],
        imports = [root_import, "."],
        deps = ["@pip//protobuf"] + deps,
        visibility = visibility,
    )

def py_grpc_library(name, srcs, proto_srcs = [], deps = [], visibility = ["//visibility:public"]):
    """Generates _pb2_grpc.py stub/servicer files for srcs using hermetic protoc_runner.

    Avoids compiling C++ gRPC source dependencies to keep cold build times fast.

    Args:
      name: Target name for the generated py_library.
      srcs: List of primary .proto files to generate _pb2_grpc.py for.
      proto_srcs: Additional .proto files needed in the Bazel sandbox for imports.
      deps: Additional Python library dependencies (typically including the matching py_proto_library).
      visibility: Visibility specifier for the generated py_library.
    """
    outs = [s[:-6] + "_pb2_grpc.py" if s.endswith(".proto") else s + "_pb2_grpc.py" for s in srcs]
    pkg_parts = native.package_name().split("/")
    depth = "../" * len(pkg_parts)
    root_import = "/".join([".."] * len(pkg_parts))
    gen_name = name + "_gen"

    all_srcs = _dedup(srcs + proto_srcs)

    native.genrule(
        name = gen_name,
        srcs = all_srcs,
        outs = outs,
        cmd = "$(location //:protoc_runner) -I. --grpc_python_out=$(RULEDIR)/" + depth + " " + " ".join(["$(location " + s + ")" for s in srcs]),
        tools = ["//:protoc_runner"],
    )

    py_library(
        name = name,
        srcs = [":" + gen_name],
        imports = [root_import, "."],
        deps = [
            "@pip//grpcio",
            "@pip//protobuf",
        ] + deps,
        visibility = visibility,
    )
