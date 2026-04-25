function nowIso() {
  return new Date().toISOString();
}

function success(command, data) {
  return {
    success: true,
    command,
    timestamp: nowIso(),
    data,
    error: null,
  };
}

function failure(command, code, message, suggestion = null, details = null) {
  return {
    success: false,
    command,
    timestamp: nowIso(),
    data: null,
    error: {
      code,
      message,
      suggestion,
      ...(details ? { details } : {}),
    },
  };
}

function writeJson(stream, payload) {
  stream.write(`${JSON.stringify(payload, null, 2)}\n`);
}

module.exports = {
  failure,
  success,
  writeJson,
};
