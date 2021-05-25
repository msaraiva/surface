defmodule Surface.Compiler.ParseTreeTranslator do
  @behaviour Surface.Compiler.NodeTranslator

  alias Surface.IOHelper

  def handle_init(state), do: state

  def handle_expression(expression, meta, state) do
    {state, {:expr, expression, to_meta(meta)}}
  end

  def handle_comment(comment, meta, state) do
    {state, {:comment, comment, meta}}
  end

  def handle_node("template", attributes, body, meta, state, context) do
    message = """
    using <template> to fill slots has been deprecated and will be removed in \
    future versions.

    Hint: replace `<template>` with `<#template>`
    """

    IOHelper.warn(message, state.caller, fn _ -> meta.line end)

    handle_node("#template", attributes, body, meta, state, context)
  end

  def handle_node("slot", attributes, body, meta, state, context) do
    message = """
    using <slot> to define component slots has been deprecated and will be removed in \
    future versions.

    Hint: replace `<slot>` with `<#slot>`
    """

    IOHelper.warn(message, state.caller, fn _ -> meta.line end)
    handle_node("#slot", attributes, body, meta, state, context)
  end

  def handle_node(name, attributes, body, meta, state, _context) do
    {state, {name, attributes, body, to_meta(meta)}}
  end

  def handle_block(name, expr, body, meta, state, _context) do
    {state, {:block, name, expr, body, to_meta(meta)}}
  end

  def handle_subblock(:default, expr, children, _meta, state, _context) do
    {state, {:block, :default, expr, children, %{}}}
  end

  def handle_subblock(name, expr, children, meta, state, _context) do
    {state, {:block, name, expr, children, to_meta(meta)}}
  end

  def handle_text(text, state) do
    {state, text}
  end

  # TODO: Update these after accepting the expression directly instead of the :root attribute
  def handle_block_expression(_block_name, nil, _state, _context) do
    []
  end

  def handle_block_expression(_block_name, {:expr, expr, expr_meta}, _state, _context) do
    meta = to_meta(expr_meta)
    [{:root, {:attribute_expr, expr, meta}, meta}]
  end

  def handle_attribute(name, {:expr, expr, expr_meta}, attr_meta, _state, _context) do
    {name, {:attribute_expr, expr, to_meta(expr_meta)}, to_meta(attr_meta)}
  end

  def handle_attribute(name, value, attr_meta, _state, _context) do
    {name, value, to_meta(attr_meta)}
  end

  def context_for_node(_name, _meta, _state) do
    nil
  end

  def context_for_subblock(_name, _meta, _state, _parent_context) do
    nil
  end

  def context_for_block(_name, _meta, _state) do
    nil
  end

  def to_meta(%{void_tag?: true} = meta) do
    Map.drop(meta, [:self_close, :line_end, :column_end])
  end

  def to_meta(meta) do
    Map.drop(meta, [:self_close, :line_end, :column_end, :void_tag?])
  end
end
