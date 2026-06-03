# MarketMySpec.Chat.ActiveTasks

GenServer backed by ETS, keyed by chat_id, holding in-flight streaming state %{task_ref, message_id, status: :streaming | :error, acc_text} (lifted from livellm). The Runner writes accumulated text here as chunks arrive; on mount/3 the LiveView reads it to restore partial assistant text and the in-progress indicator after a reload (R4). The entry is cleared on :stream_done / :stream_error. Started in the application supervision tree alongside the Task.Supervisor.

## Type

module
