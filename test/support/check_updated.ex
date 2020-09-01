defmodule Surface.CheckUpdated do
  use Surface.LiveComponent

  @doc "The id of the component"
  property id, :string, required: true

  @doc "The process to send the :updated message"
  property dest, :any, required: true

  @doc "Something to inspect"
  property content, :any, default: %{}

  def update(assigns, socket) do
    if connected?(socket) do
      send(assigns.dest, {:updated, assigns.id})
    end

    {:ok, assign(socket, assigns)}
  end

  def render(assigns) do
    ~H"""
    <div>{{ inspect(@content) }}</div>
    """
  end
end
