"""
Types definitions.
"""

import typing as t

from server.server_types import Context, RouteFunction, ServerRequest


class Middlewares(t.TypedDict):
    """
    A list of available middlewares.
    """

    route_map: t.Dict[str, t.List[t.Callable[[ServerRequest, Context], t.Any]]]


class RouteHandler(t.TypedDict):
    """
    A registered route handler.
    """

    middleware: t.List[t.Callable[[ServerRequest, Context], t.Any]]
    method: RouteFunction
