const { failure, success, writeJson } = require("./result");
const { VERSION } = require("./version");

const COMMANDS = [
  ["init <project-id> <project-dir>", "Register or update a local project."],
  ["task <project-id> <task-file>", "Append a task file to a project queue."],
  ["status", "Show project, task, heartbeat, risk, and next-action status."],
  ["doctor", "Run local preflight checks."],
  ["decisions", "List pending local decision fallback requests."],
  ["approve <decision-id>", "Approve a pending local decision request."],
  ["reject <decision-id>", "Reject a pending local decision request."],
  ["risk [--file path] [--command text] [--scope scope]", "Evaluate static risk rulebook matches."],
  ["request-decision <project-id> <task-id>", "Create a local decision request fixture for prototype verification."],
];

function helpText() {
  const lines = [
    "Hermes CLI prototype",
    "",
    "Usage:",
    "  hermes <command> [args] [--json]",
    "  hermes --help",
    "  hermes --version",
    "",
    "Commands:",
  ];

  const width = Math.max(...COMMANDS.map(([usage]) => usage.length));
  for (const [usage, description] of COMMANDS) {
    lines.push(`  ${usage.padEnd(width)}  ${description}`);
  }

  lines.push(
    "",
    "Prototype scope:",
    "  Local CLI, file-bus/state foundations, project/task/status, doctor, risk, and local decisions.",
    "  Live Claude/Codex tmux orchestration and remote adapters are intentionally deferred."
  );

  return `${lines.join("\n")}\n`;
}

function parseGlobalArgs(argv) {
  const args = [];
  let json = false;

  for (const arg of argv) {
    if (arg === "--json") {
      json = true;
    } else {
      args.push(arg);
    }
  }

  return { args, json };
}

function commandName(args) {
  if (args.length === 0) return "hermes";
  return `hermes ${args.join(" ")}`;
}

function notImplemented(command, feature) {
  return failure(
    command,
    "NOT_IMPLEMENTED",
    `${feature} is not implemented in the current prototype phase.`,
    "Continue through the v1.1 roadmap phases or run the matching later-phase command after implementation."
  );
}

async function runCommand(args) {
  const [command] = args;
  const fullCommand = commandName(args);

  switch (command) {
    case "init":
      return notImplemented(fullCommand, "Project registration");
    case "task":
      return notImplemented(fullCommand, "Task append");
    case "status":
      return notImplemented(fullCommand, "Status read model");
    case "doctor":
      return notImplemented(fullCommand, "Doctor checks");
    case "decisions":
      return notImplemented(fullCommand, "Decision listing");
    case "approve":
    case "reject":
      return notImplemented(fullCommand, "Decision response");
    case "risk":
      return notImplemented(fullCommand, "Risk evaluation");
    case "request-decision":
      return notImplemented(fullCommand, "Decision request creation");
    default:
      return failure(
        fullCommand,
        "UNKNOWN_COMMAND",
        `Unknown command: ${command}`,
        "Run hermes --help to see supported prototype commands."
      );
  }
}

async function main(argv, io) {
  const { args, json } = parseGlobalArgs(argv);

  if (args.length === 0 || args[0] === "--help" || args[0] === "-h") {
    if (json) {
      writeJson(io.stdout, success("hermes --help", { version: VERSION, commands: COMMANDS }));
    } else {
      io.stdout.write(helpText());
    }
    return 0;
  }

  if (args[0] === "--version" || args[0] === "-v") {
    if (json) {
      writeJson(io.stdout, success("hermes --version", { version: VERSION }));
    } else {
      io.stdout.write(`${VERSION}\n`);
    }
    return 0;
  }

  const payload = await runCommand(args, io);
  writeJson(io.stdout, payload);
  return payload.success ? 0 : 1;
}

module.exports = {
  COMMANDS,
  helpText,
  main,
  parseGlobalArgs,
  runCommand,
};
