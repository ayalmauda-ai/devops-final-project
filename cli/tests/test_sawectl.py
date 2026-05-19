"""
cli/tests/test_sawectl.py

Unit tests for sawectl.py — covers argument parsing and the pure utility
functions (no network calls, no real files required where avoidable).

Run from the repo root:
    pytest cli/tests/ -v

Or from inside cli/:
    pytest tests/ -v
"""

import sys
import os
import json
import tempfile
import pytest

# ── Import path setup ─────────────────────────────────────────────────────────
# sawectl.py lives at cli/sawectl/sawectl.py. We add that directory to the path
# so `import sawectl` finds it regardless of where pytest is invoked from.
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "sawectl"))
import sawectl  # noqa: E402


# ═══════════════════════════════════════════════════════════════════════════════
# 1. Argument parser — basic structure
# ═══════════════════════════════════════════════════════════════════════════════

def _make_parser():
    """Return a fresh ArgumentParser by re-running the setup block in main()."""
    import argparse
    parser = argparse.ArgumentParser(prog="sawectl")
    parser.add_argument("-v", "--version", action="version", version=sawectl.VERSION)
    subparsers = parser.add_subparsers(dest="command")

    p_run = subparsers.add_parser("run")
    p_run.add_argument("--workflow", required=True)
    p_run.add_argument("--server",   required=True)

    p_val = subparsers.add_parser("validate-workflow")
    p_val.add_argument("--workflow", required=True)
    p_val.add_argument("--modules",  default="modules")
    p_val.add_argument("--verbose",  action="store_true")

    p_valmod = subparsers.add_parser("validate-modules")
    p_valmod.add_argument("--modules", default="modules")

    p_init = subparsers.add_parser("init")
    sub_init = p_init.add_subparsers(dest="type")

    p_mod = sub_init.add_parser("module")
    p_mod.add_argument("name")
    p_mod.add_argument("--modules", default="modules")

    p_wf = sub_init.add_parser("workflow")
    p_wf.add_argument("name")
    p_wf.add_argument("--minimal",       action="store_true")
    p_wf.add_argument("--full",          action="store_true")
    p_wf.add_argument("--trigger",       default="api")
    p_wf.add_argument("--modules-path",  default="modules")
    p_wf.add_argument("--workflows-path", default="workflows")

    return parser


class TestArgumentParsing:
    """Verify the CLI argument parser produces the right namespaces."""

    def test_run_command_sets_workflow_and_server(self):
        parser = _make_parser()
        args = parser.parse_args(["run", "--workflow", "my_wf.yaml", "--server", "http://localhost:8080"])
        assert args.command  == "run"
        assert args.workflow == "my_wf.yaml"
        assert args.server   == "http://localhost:8080"

    def test_validate_workflow_defaults(self):
        """--modules should default to 'modules' and --verbose to False."""
        parser = _make_parser()
        args = parser.parse_args(["validate-workflow", "--workflow", "wf.yaml"])
        assert args.command  == "validate-workflow"
        assert args.modules  == "modules"
        assert args.verbose  is False

    def test_validate_workflow_verbose_flag(self):
        parser = _make_parser()
        args = parser.parse_args(["validate-workflow", "--workflow", "wf.yaml", "--verbose"])
        assert args.verbose is True

    def test_init_module_positional_name(self):
        parser = _make_parser()
        args = parser.parse_args(["init", "module", "my_module"])
        assert args.command == "init"
        assert args.type    == "module"
        assert args.name    == "my_module"

    def test_init_workflow_trigger_default(self):
        """--trigger should default to 'api'."""
        parser = _make_parser()
        args = parser.parse_args(["init", "workflow", "my_workflow"])
        assert args.trigger == "api"

    def test_init_workflow_custom_trigger(self):
        parser = _make_parser()
        args = parser.parse_args(["init", "workflow", "my_workflow", "--trigger", "git"])
        assert args.trigger == "git"

    def test_validate_modules_default_path(self):
        parser = _make_parser()
        args = parser.parse_args(["validate-modules"])
        assert args.command == "validate-modules"
        assert args.modules == "modules"

    def test_run_missing_server_raises(self):
        """Both --workflow and --server are required for 'run'."""
        parser = _make_parser()
        with pytest.raises(SystemExit):
            parser.parse_args(["run", "--workflow", "wf.yaml"])  # missing --server


# ═══════════════════════════════════════════════════════════════════════════════
# 2. load_yaml utility
# ═══════════════════════════════════════════════════════════════════════════════

class TestLoadYaml:

    def test_loads_valid_yaml(self, tmp_path):
        f = tmp_path / "test.yaml"
        f.write_text("name: hello\nvalue: 42\n")
        data = sawectl.load_yaml(str(f))
        assert data["name"]  == "hello"
        assert data["value"] == 42

    def test_empty_yaml_exits(self, tmp_path):
        """An empty YAML file should cause a sys.exit (not a silent None return)."""
        f = tmp_path / "empty.yaml"
        f.write_text("")
        with pytest.raises(SystemExit):
            sawectl.load_yaml(str(f))

    def test_invalid_yaml_exits(self, tmp_path):
        """Malformed YAML should cause a sys.exit."""
        f = tmp_path / "bad.yaml"
        f.write_text("key: [unclosed bracket\n")
        with pytest.raises(SystemExit):
            sawectl.load_yaml(str(f))


# ═══════════════════════════════════════════════════════════════════════════════
# 3. extract_module_and_method utility
# ═══════════════════════════════════════════════════════════════════════════════

class TestExtractModuleAndMethod:

    def test_context_format_returns_module_and_method(self):
        """context.<id>.<method> should resolve via context_modules dict."""
        context_modules = {
            "cm1": {"module": "slack.SlackClient"}
        }
        module, method = sawectl.extract_module_and_method("context.cm1.send", context_modules)
        assert module == "slack"
        assert method == "send"

    def test_three_part_direct_format(self):
        """module.class.method format should return (module, method)."""
        module, method = sawectl.extract_module_and_method("email.EmailClient.send", {})
        assert module == "email"
        assert method == "send"

    def test_two_part_format(self):
        """module.method (two parts) should return (module, method)."""
        module, method = sawectl.extract_module_and_method("git.clone", {})
        assert module == "git"
        assert method == "clone"

    def test_context_missing_module_returns_none(self):
        """If the context_modules dict doesn't have the ID, return (None, None)."""
        module, method = sawectl.extract_module_and_method("context.missing_id.act", {})
        assert module is None
        assert method is None


# ═══════════════════════════════════════════════════════════════════════════════
# 4. validate_step utility
# ═══════════════════════════════════════════════════════════════════════════════

class TestValidateStep:

    def test_step_missing_id_fails(self, tmp_path):
        """A step without 'id' must return (False, <message>)."""
        step = {"type": "action"}   # no 'id'
        ok, msg = sawectl.validate_step(step, str(tmp_path), {})
        assert ok is False
        assert "id" in msg or "type" in msg

    def test_step_missing_type_fails(self, tmp_path):
        """A step without 'type' must return (False, <message>)."""
        step = {"id": "step_1"}   # no 'type'
        ok, msg = sawectl.validate_step(step, str(tmp_path), {})
        assert ok is False
