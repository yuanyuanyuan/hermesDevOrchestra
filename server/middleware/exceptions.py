"""
Middleware exceptions.
"""


class WorkerProtocolError(Exception):
    """Raised when the worker violates the protocol contract.

    This replaces the old generic RuntimeError used throughout the middleware layer.
    It allows callers to distinguish protocol violations (unstable, retry-worthy)
    from truly unexpected errors (potentially stable, worth surfacing).
    """

    pass
