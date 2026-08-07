defmodule IeeeTamuPortalWeb.PaginationComponents do
  use Phoenix.Component

  alias Phoenix.LiveView.JS

  @page_sizes [10, 25, 50, 100]

  attr :meta, :any, required: true
  attr :path, :any, required: true

  def pagination(assigns) do
    ~H"""
    <div class="flex items-center justify-center min-h-10">
      <Flop.Phoenix.pagination
        meta={@meta}
        path={@path}
        page_links={2}
        page_link_attrs={[
          class:
            "relative inline-flex items-center px-4 py-2 text-sm font-medium text-gray-500 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
        ]}
        current_page_link_attrs={[
          class:
            "relative inline-flex items-center px-4 py-2 text-sm font-medium text-white bg-indigo-600 border border-indigo-600 rounded-md"
        ]}
        page_list_attrs={[class: "flex space-x-1"]}
        disabled_link_attrs={[
          class:
            "relative inline-flex items-center px-4 py-2 text-sm font-medium text-gray-300 bg-white border border-gray-300 cursor-default rounded-md"
        ]}
        class="flex items-center space-x-2"
      >
        <:previous attrs={[
          class:
            "relative inline-flex items-center px-4 py-2 text-sm font-medium text-gray-500 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
        ]}>
          Prev
        </:previous>
        <:next attrs={[
          class:
            "relative inline-flex items-center px-4 py-2 text-sm font-medium text-gray-500 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
        ]}>
          Next
        </:next>
        <:ellipsis>
          <span
            class="relative inline-flex items-center py-2 text-sm font-medium text-gray-500"
            aria-hidden="true"
          >
            &hellip;
          </span>
        </:ellipsis>
      </Flop.Phoenix.pagination>
    </div>
    """
  end

  attr :meta, :any, required: true
  attr :path, :any, required: true

  def page_size_selector(assigns) do
    assigns = assign(assigns, :sizes, @page_sizes)
    assigns = assign(assigns, :current_size, assigns.meta.page_size)

    ~H"""
    <div class="flex items-center gap-1">
      <span class="text-sm font-medium text-gray-700 mr-1">Show</span>
      <button
        :for={size <- @sizes}
        type="button"
        phx-click={JS.patch("#{@path}?page_size=#{size}")}
        class={[
          "px-2 py-1 text-sm rounded-md transition-colors",
          if(size == @current_size,
            do: "bg-indigo-600 text-white",
            else: "text-gray-700 hover:bg-gray-100"
          )
        ]}
      >
        {size}
      </button>
    </div>
    """
  end
end
