defmodule Surface.TypeHandler.Event do
  @moduledoc false

  use Surface.TypeHandler

  @impl true
  def expr_to_quoted(type, attribute_name, clauses, opts, meta, original) do
    quoted_expr = super(type, attribute_name, clauses, opts, meta, original)
    caller_cid = Surface.AST.Meta.quoted_caller_cid(meta)

    quote generated: true do
      unquote(__MODULE__).maybe_update_target(unquote(quoted_expr), unquote(caller_cid))
    end
  end

  @impl true
  def expr_to_value([nil], []) do
    {:ok, nil}
  end

  def expr_to_value([%{name: _, target: _} = event], []) do
    {:ok, event}
  end

  def expr_to_value([name], opts) when is_atom(name) or is_binary(name) do
    {:ok, %{name: to_string(name), target: Keyword.get(opts, :target)}}
  end

  def expr_to_value(clauses, opts) do
    {:error, {clauses, opts}}
  end

  def maybe_update_target(%{target: nil} = event, nil) do
    %{event | target: :live_view}
  end

  def maybe_update_target(%{target: nil} = event, cid) do
    %{event | target: cid}
  end

  def maybe_update_target(event, _cid) do
    event
  end
end
