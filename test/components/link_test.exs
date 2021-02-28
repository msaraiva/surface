defmodule Surface.Components.LinkTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.Link

  defmodule ComponentWithLink do
    use Surface.LiveComponent

    def render(assigns) do
      ~H"""
      <div>
        <Link to="/users/1" click="my_click"/>
      </div>
      """
    end

    def handle_event(_, _, socket) do
      {:noreply, socket}
    end
  end

  test "creates a link with label" do
    html =
      render_surface do
        ~H"""
        <Link label="user" to="/users/1" />
        """
      end

    assert html =~ """
           <a href="/users/1">user</a>
           """
  end

  test "creates a link without label" do
    html =
      render_surface do
        ~H"""
        <Link to="/users/1" />
        """
      end

    assert html =~ """
           <a href="/users/1"></a>
           """
  end

  test "creates a link with default slot" do
    html =
      render_surface do
        ~H"""
        <Link to="/users/1"><span>user</span></Link>
        """
      end

    assert html =~ """
           <a href="/users/1"><span>user</span></a>
           """
  end

  test "setting the class" do
    html =
      render_surface do
        ~H"""
        <Link label="user" to="/users/1" class="link" />
        """
      end

    assert html =~ """
           <a class="link" href="/users/1">user</a>
           """
  end

  test "setting multiple classes" do
    html =
      render_surface do
        ~H"""
        <Link label="user" to="/users/1" class="link primary" />
        """
      end

    assert html =~ """
           <a class="link primary" href="/users/1">user</a>
           """
  end

  test "passing other options" do
    csrf_token = Plug.CSRFProtection.get_csrf_token()

    html =
      render_surface do
        ~H"""
        <Link label="user" to="/users/1" method={{ :delete }} opts={{ data: [confirm: "Really?"] }} />
        """
      end

    assert html =~ """
           <a data-confirm="Really?" data-csrf="#{csrf_token}" data-method="delete" data-to="/users/1" rel="nofollow" href="/users/1">user</a>
           """
  end

  test "click event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <Link to="/users/1" click="my_click" />
        """
      end

    assert html =~ """
           <a phx-click="my_click" href="/users/1"></a>
           """
  end

  test "click event with @myself as target" do
    html =
      render_surface do
        ~H"""
        <ComponentWithLink id="comp"/>
        """
      end

    assert html =~ ~r"""
           <div>
             <a phx-click="my_click" phx-target=".+" href="/users/1"></a>
           </div>
           """
  end

  describe "is compatible with phoenix link/2" do
    test "link with post" do
      csrf_token = Plug.CSRFProtection.get_csrf_token()

      html =
        render_surface do
          ~H"""
          <Link label="hello" to="/world" method={{ :post }} />
          """
        end

      assert html =~
               ~s[<a data-csrf="#{csrf_token}" data-method="post" data-to="/world" rel="nofollow" href="/world">hello</a>]
    end

    test "link with %URI{}" do
      url = "http://surface-demo.msaraiva.io/"

      assert render_surface(do: ~H[<Link label="elixir" to={{ url }} />]) ==
               render_surface(do: ~H[<Link label="elixir" to={{ URI.parse(url) }} />])

      path = "/surface"

      assert render_surface(do: ~H[<Link label="elixir" to={{ path }} />]) ==
               render_surface(do: ~H[<Link label="elixir" to={{ URI.parse(path) }} />])
    end

    test "link with put/delete" do
      csrf_token = Plug.CSRFProtection.get_csrf_token()

      html =
        render_surface do
          ~H"""
          <Link label="hello" to="/world" method={{ :put }} />
          """
        end

      assert html =~
               ~s[<a data-csrf="#{csrf_token}" data-method="put" data-to="/world" rel="nofollow" href="/world">hello</a>]
    end

    test "link with put/delete without csrf_token" do
      html =
        render_surface do
          ~H"""
          <Link label="hello" to="/world" method={{ :put }} opts={{ csrf_token: false }} />
          """
        end

      assert html =~
               ~s[<a data-method="put" data-to="/world" rel="nofollow" href="/world">hello</a>]
    end

    test "link with scheme" do
      html = render_surface(do: ~H[<Link to="/javascript:alert(<1>)" />])
      assert html =~ ~s[<a href="/javascript:alert(&lt;1&gt;)"></a>]

      html = render_surface(do: ~H[<Link to={{ {:safe, "/javascript:alert(<1>)"} }} />])
      assert html =~ ~s[<a href="/javascript:alert(<1>)"></a>]

      html = render_surface(do: ~H[<Link to={{ {:javascript, "alert(<1>)"} }} />])
      assert html =~ ~s[<a href="javascript:alert(&lt;1&gt;)"></a>]

      html = render_surface(do: ~H[<Link to={{ {:javascript, 'alert(<1>)'} }} />])
      assert html =~ ~s[<a href="javascript:alert(&lt;1&gt;)"></a>]

      html = render_surface(do: ~H[<Link to={{ {:javascript, {:safe, "alert(<1>)"}} }} />])
      assert html =~ ~s[<a href="javascript:alert(<1>)"></a>]

      html = render_surface(do: ~H[<Link to={{ {:javascript, {:safe, 'alert(<1>)'}} }} />])
      assert html =~ ~s[<a href="javascript:alert(<1>)"></a>]
    end
  end
end
