"""Ownership checks for endpoints that take an account id in the URL.

Every view in this app receives the account it should act on as a URL
parameter. ``IsAuthenticated`` only proves that somebody is signed in — it says
nothing about whether that person owns the record they just asked for. Without
the checks below, changing one integer in a URL reads, rewrites or permanently
deletes another user's menstrual health history.

Identity comes from the token, never from the path.
"""

from functools import wraps

from rest_framework import status
from rest_framework.response import Response

from .models import SuperUser


def _forbidden():
    """One response for every refusal.

    Deliberately says nothing about whether the account exists: a different
    reply for "no such user" would let anyone enumerate which account ids are
    real, which is disclosure in itself for an app like this.
    """
    return Response(
        {'error': 'You do not have access to this record.'},
        status=status.HTTP_403_FORBIDDEN,
    )


def manages(actor, target_id):
    """Whether ``actor`` is a cohort manager for the account ``target_id``.

    Checked through the many-to-many field, NOT through ``actor.managed_users``.
    That reverse name belongs to the ``user`` foreign key — the manager side —
    so it returns the SuperUser rows this person owns rather than the people
    they manage. Using it here would authorise the wrong thing entirely.
    """
    if target_id is None:
        return False
    return SuperUser.objects.filter(
        user_id=actor.id, managed_users__id=target_id
    ).exists()


def _authenticated(request):
    actor = getattr(request, 'user', None)
    return actor if actor is not None and actor.is_authenticated else None


def owns_account(view):
    """Caller must BE the account named in the URL, or manage it.

    Field staff legitimately act for the girls in their cohort, so managers are
    allowed through — but only for accounts actually linked to them.
    """

    @wraps(view)
    def wrapper(request, *args, **kwargs):
        actor = _authenticated(request)
        if actor is None:
            return _forbidden()
        target = kwargs.get('user_id')
        if str(actor.id) == str(target) or manages(actor, target):
            return view(request, *args, **kwargs)
        return _forbidden()

    return wrapper


def is_self(view):
    """Caller must BE the superuser named in the URL.

    Stricter than :func:`owns_account` on purpose: acting *as* another manager
    is never legitimate, so there is no delegation path here.
    """

    @wraps(view)
    def wrapper(request, *args, **kwargs):
        actor = _authenticated(request)
        if actor is None:
            return _forbidden()
        if str(actor.id) == str(kwargs.get('superuser_id')):
            return view(request, *args, **kwargs)
        return _forbidden()

    return wrapper
