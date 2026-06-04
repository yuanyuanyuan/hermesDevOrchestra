"""
Defines the way the VPC module for Update processes requests.
"""

import typing as t

from server.framework import Framework
from server.frameworks.aws_lambda import LambdaEvent
from server.middleware.types import Middlewares, RouteHandler
from server.modules.server_commons.server_request_util import ServerRequestUtil
from server.server_types import Context, DecoratedRequestFunction, ServerRequest
from server.util.version import VersionedDict

from server.middleware.exceptions import WorkerProtocolError

from . import _internal

if t.TYPE_CHECKING:
    from server.modules.server_commons.base_server_options import BaseServerOptions


class UpdateVPCMiddleware(t.NamedTuple):
    """Namespace returned by create_update_vpc_middleware.

    Attributes:
        event_handler: Fastify-style handler for Lambda events.
        response_handler: Fastify-style handler for Lambda responses.
    """

    event_handler: t.Callable[[LambdaEvent, Context], t.Any]
    response_handler: t.Callable[[LambdaEvent, Context], t.Any]


class ResponseEnricher(t.NamedTuple):
    """Enriches the response with the standard fields for an Update VPC response."""

    application_name: str
    server_version: str
    preloaded_extras: t.Optional[VersionedDict]

    def enrich(
        self,
        response: ServerRequest,
        extras: t.Optional[VersionedDict] = None,
    ):
        """Enriches the response with the standard fields for an Update VPC response."""
        response.headers.update(
            {
                "X-Update-Version": self.server_version,
                "X-Update-Application": self.application_name,
            }
        )

        if self.preloaded_extras:
            response.headers.update(self.preloaded_extras.value)

        if extras:
            response.headers.update(extras.value)


# -------------------------------------------------
# PUBLIC HELPERS (used by tests and Lambda entrypoint)
# -------------------------------------------------


def extract_versioned_dict(
    lambda_event: LambdaEvent,
    context: Context,
    route_map: t.Dict[str, t.List[t.Callable[[ServerRequest, Context], t.Any]]],
    result: ServerRequest,
    enricher: ResponseEnricher,
    add_headers: t.Optional[VersionedDict] = None,
) -> ServerRequest:
    """Extracts a ServerRequest from a Lambda event and enriches it with the standard fields."""
    ServerRequestUtil.add_versioned_request_dict(result)

    path = lambda_event.get("path", "/")
    method = lambda_event.get("httpMethod", "GET")

    request = ServerRequest(path=path, method=method, path_parameters={})

    enricher.enrich(result, add_headers)

    # Check if the path and method match any registered route
    matching_route: t.Optional[RouteHandler] = None
    for registered_path, route in route_map.items():
        if registered_path == path and request.method == route.get("method", "GET"):
            matching_route = route
            break

    if matching_route:
        for middleware in matching_route["middleware"]:
            middleware(request, context)
    else:
        raise WorkerProtocolError(f"Route not found: {method} {path}")

    return result


def extract_api_gateway_response(
    lambda_event: LambdaEvent,
    context: Context,
    route_map: t.Dict[str, t.List[t.Callable[[ServerRequest, Context], t.Any]]],
    result: ServerRequest,
    enricher: ResponseEnricher,
) -> ServerRequest:
    """Extracts a ServerRequest from an API Gateway event."""
    return extract_versioned_dict(
        lambda_event,
        context,
        route_map,
        result,
        enricher,
    )


# -------------------------------------------------
# MIDDLEWARE FACTORY
# -------------------------------------------------


def create_update_vpc_middleware(
    filter_prefix: t.Optional[str] = None,
    server_version: str = "0.0.1",
    raw_mode: bool = False,
    extra_routes: t.Optional[t.List[DecoratedRequestFunction]] = None,
    default_headers: t.Optional[VersionedDict] = None,
) -> UpdateVPCMiddleware:
    """Create an Update VPC middleware that handles Lambda events and responses.

    This is the single entry point for setting up the middleware layer.
    It builds the route map internally and returns a namespace with both handlers.

    Args:
        filter_prefix: Route prefix filter.
        server_version: Current server version.
        raw_mode: If True, skip protocol validation.
        extra_routes: Additional route handlers to register.
        default_headers: Default headers to add to all responses.

    Returns:
        UpdateVPCMiddleware with event_handler and response_handler.
    """
    # Build route map locally (no global registry)
    route_map: t.Dict[str, t.List[t.Callable[[ServerRequest, Context], t.Any]]] = {}

    if extra_routes:
        for route in extra_routes:
            path = route.get("path", "/")
            route_map[path] = {
                "method": route.get("method", "GET"),
                "middleware": route.get("middleware", []),
            }

    enricher = ResponseEnricher(
        application_name="update",
        server_version=server_version,
        preloaded_extras=default_headers,
    )

    def _event_handler(lambda_event: LambdaEvent, context: Context) -> ServerRequest:
        """Fastify-style handler for Lambda events."""
        path = lambda_event.get("path", "/")
        method = lambda_event.get("httpMethod", "GET")
        request = ServerRequest(path=path, method=method, path_parameters={})

        # Check if the route exists
        if path not in route_map:
            raise WorkerProtocolError(f"Route not found: {method} {path}")

        route = route_map[path]
        if route.get("method", "GET") != method:
            raise WorkerProtocolError(f"Method not allowed: {method} {path}")

        # Apply middleware
        for middleware in route.get("middleware", []):
            middleware(request, context)

        result = ServerRequest(path=path, method=method, path_parameters={})
        enricher.enrich(result)
        return result

    def _response_handler(lambda_event: LambdaEvent, context: Context) -> ServerRequest:
        """Fastify-style handler for Lambda responses."""
        result = ServerRequest(
            path=lambda_event.get("path", "/"),
            method=lambda_event.get("httpMethod", "GET"),
            path_parameters={},
        )
        return extract_api_gateway_response(
            lambda_event,
            context,
            route_map,
            result,
            enricher,
        )

    return UpdateVPCMiddleware(
        event_handler=_event_handler,
        response_handler=_response_handler,
    )
