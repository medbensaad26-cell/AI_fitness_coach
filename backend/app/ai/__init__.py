"""AI / RAG coaching layer.

Person A owns this package (AI / RAG). Person B calls the public functions from
routers — do not put FastAPI routes here.

Import concrete modules directly, e.g.::

    from app.ai.chat import chat_completion
    from app.ai.generate_program import generate_program
    from app.ai.history import index_session_history
    from app.ai.live_coach import (
        after_exercise_feedback,
        end_session_coach,
        mid_session_coach,
        start_session_check_in,
    )
    from app.ai.retrieval import retrieve_knowledge
    from app.ai.suggest_next import suggest_next_program
"""

from app.ai.chat import chat_completion

__all__ = [
    "after_exercise_feedback",
    "chat_completion",
    "embed_texts",
    "end_session_coach",
    "generate_program",
    "index_session_history",
    "mid_session_coach",
    "retrieve_knowledge",
    "start_session_check_in",
    "suggest_next_program",
]


def __getattr__(name: str):
    # Lazy exports so light imports do not require DB/pgvector/fastembed.
    if name == "embed_texts":
        from app.ai.embeddings import embed_texts

        return embed_texts
    if name == "retrieve_knowledge":
        from app.ai.retrieval import retrieve_knowledge

        return retrieve_knowledge
    if name == "generate_program":
        from app.ai.generate_program import generate_program

        return generate_program
    if name == "index_session_history":
        from app.ai.history import index_session_history

        return index_session_history
    if name == "suggest_next_program":
        from app.ai.suggest_next import suggest_next_program

        return suggest_next_program
    if name == "start_session_check_in":
        from app.ai.live_coach import start_session_check_in

        return start_session_check_in
    if name == "after_exercise_feedback":
        from app.ai.live_coach import after_exercise_feedback

        return after_exercise_feedback
    if name == "end_session_coach":
        from app.ai.live_coach import end_session_coach

        return end_session_coach
    if name == "mid_session_coach":
        from app.ai.live_coach import mid_session_coach

        return mid_session_coach
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")
