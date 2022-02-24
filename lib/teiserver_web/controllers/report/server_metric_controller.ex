defmodule TeiserverWeb.Report.ServerMetricController do
  use CentralWeb, :controller
  alias Teiserver.Telemetry
  alias Central.Helpers.{TimexHelper, DatePresets}
  alias Teiserver.Telemetry.{GraphDayLogsTask, ExportServerMetricsTask, GraphMinuteLogsTask}
  import Central.Helpers.NumberHelper, only: [int_parse: 1]

  plug(AssignPlug,
    site_menu_active: "teiserver_report",
    sub_menu_active: "server_metric"
  )

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Moderator,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}

  plug(:add_breadcrumb, name: 'Teiserver', url: '/teiserver')
  plug(:add_breadcrumb, name: 'Reports', url: '/teiserver/reports')
  plug(:add_breadcrumb, name: 'Server metrics', url: '/teiserver/reports/server/day_metrics')

  # DAILY METRICS
  @spec day_metrics_list(Plug.Conn.t(), map) :: Plug.Conn.t()
  def day_metrics_list(conn, params) do
    logs =
      Telemetry.list_server_day_logs(
        # search: [user_id: params["user_id"]],
        # joins: [:user],
        order: "Newest first",
        limit: 31
      )

    filter = params["filter"] || "default"

    conn
    |> assign(:logs, logs)
    |> assign(:filter, filter)
    |> add_breadcrumb(name: "Daily", url: conn.request_path)
    |> render("day_metrics_list.html")
  end

  @spec day_metrics_show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def day_metrics_show(conn, %{"date" => date_str}) do
    date = TimexHelper.parse_ymd(date_str)
    log = Telemetry.get_server_day_log(date)

    users =
      [log]
      |> Telemetry.user_lookup()

    conn
    |> assign(:date, date)
    |> assign(:data, log.data)
    |> assign(:users, users)
    |> add_breadcrumb(name: "Daily - #{date_str}", url: conn.request_path)
    |> render("day_metrics_show.html")
  end

  @spec day_metrics_today(Plug.Conn.t(), map) :: Plug.Conn.t()
  def day_metrics_today(conn, _params) do
    data = Telemetry.get_todays_log()

    users =
      [%{data: data}]
      |> Telemetry.user_lookup()

    conn
    |> assign(:date, Timex.today())
    |> assign(:data, data)
    |> assign(:users, users)
    |> add_breadcrumb(name: "Daily - Today (partial)", url: conn.request_path)
    |> render("day_metrics_show.html")
  end

  @spec day_metrics_export_form(Plug.Conn.t(), map) :: Plug.Conn.t()
  def day_metrics_export_form(conn, _params) do
    conn
    |> assign(:params, %{
      "date_preset" => "All time"
    })
    |> assign(:presets, DatePresets.long_ranges)
    |> render("day_metrics_export_form.html")
  end

  @spec day_metrics_export_post(Plug.Conn.t(), map) :: Plug.Conn.t()
  def day_metrics_export_post(conn, %{"report" => params}) do
    data = ExportServerMetricsTask.perform(params)

    conn
    |> put_resp_content_type("application/json")
    |> put_resp_header("content-disposition", "attachment; filename=\"server_metrics.json\"")
    |> send_resp(200, data)
  end

  def day_metrics_graph(conn, params) do
    params = Map.merge(params, %{
      "days" => Map.get(params, "days", 31) |> int_parse
    })

    logs =
      Telemetry.list_server_day_logs(
        # search: [user_id: params["user_id"]],
        # joins: [:user],
        order: "Newest first",
        limit: params["days"]
      )
      |> Enum.reverse()

    {field_list, f} = case Map.get(params, "fields", "unique_users") do
      "unique_users" ->
        {["aggregates.stats.unique_users", "aggregates.stats.unique_players"], fn x -> x end}

      "peak_users" ->
        {["aggregates.stats.peak_user_counts.total", "aggregates.stats.peak_user_counts.player"], fn x -> x end}

      "days" ->
        {["aggregates.minutes.player", "aggregates.minutes.spectator", "aggregates.minutes.lobby", "aggregates.minutes.menu", "aggregates.minutes.total"], fn x -> round(x/60/24) end}
    end

    extra_params = %{"field_list" => field_list}

    columns = GraphDayLogsTask.perform(logs, Map.merge(params, extra_params), f)

    key = logs
    |> Enum.map(fn log -> log.date |> TimexHelper.date_to_str(format: :ymd) end)

    conn
    |> assign(:params, params)
    |> assign(:columns, columns)
    |> assign(:key, key)
    |> add_breadcrumb(name: "Daily - Graph", url: conn.request_path)
    |> render("day_metrics_graph.html")
  end


  # MONTHLY METRICS
  @spec month_metrics_list(Plug.Conn.t(), map) :: Plug.Conn.t()
  def month_metrics_list(conn, _params) do
    logs =
      Telemetry.list_server_month_logs(
        # search: [user_id: params["user_id"]],
        # joins: [:user],
        order: "Newest first",
        limit: 36
      )

    conn
    |> assign(:logs, logs)
    |> add_breadcrumb(name: "Monthly", url: conn.request_path)
    |> render("month_metrics_list.html")
  end

  @spec month_metrics_show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def month_metrics_show(conn, %{"year" => year, "month" => month}) do
    log = Telemetry.get_server_month_log({year, month})

    conn
    |> assign(:year, year)
    |> assign(:month, month)
    |> assign(:data, log.data)
    |> add_breadcrumb(name: "Monthly - #{month}/#{year}", url: conn.request_path)
    |> render("month_metrics_show.html")
  end

  @spec month_metrics_today(Plug.Conn.t(), map) :: Plug.Conn.t()
  def month_metrics_today(conn, _params) do
    data = Telemetry.get_this_months_log()

    conn
    |> assign(:year, Timex.today().year)
    |> assign(:month, Timex.today().month)
    |> assign(:data, data)
    |> add_breadcrumb(name: "Monthly - This month (partial)", url: conn.request_path)
    |> render("month_metrics_show.html")
  end

  def month_metrics_graph(conn, params) do
    params = Map.merge(params, %{
      "months" => Map.get(params, "months", 12) |> int_parse
    })

    logs =
      Telemetry.list_server_month_logs(
        # search: [user_id: params["user_id"]],
        # joins: [:user],
        order: "Newest first",
        limit: params["months"]
      )
      |> Enum.reverse()

    {field_list, f} = case Map.get(params, "fields", "unique_users") do
      "unique_users" ->
        {["aggregates.stats.unique_users", "aggregates.stats.unique_players"], fn x -> x end}

      "peak_users" ->
        {["aggregates.stats.peak_users", "aggregates.stats.peak_players"], fn x -> x end}

      "days" ->
        {["aggregates.minutes.player", "aggregates.minutes.spectator", "aggregates.minutes.lobby", "aggregates.minutes.menu", "aggregates.minutes.total"], fn x -> round(x/60/24) end}
    end

    extra_params = %{"field_list" => field_list}

    columns = GraphDayLogsTask.perform(logs, Map.merge(params, extra_params), f)

    key = logs
    |> Enum.map(fn log -> {log.year,log.month, 1} |> TimexHelper.date_to_str(format: :ymd) end)

    conn
    |> assign(:params, params)
    |> assign(:columns, columns)
    |> assign(:key, key)
    |> add_breadcrumb(name: "Monthly - Graph", url: conn.request_path)
    |> render("month_metrics_graph.html")
  end

  # DAILY METRICS
  @spec now_list(Plug.Conn.t(), map) :: Plug.Conn.t()
  def now_list(conn, _params) do
    logs =
      Telemetry.list_server_minute_logs(
        order: "Newest first",
        limit: 30
      )
      |> Enum.reverse

    columns_players = GraphMinuteLogsTask.perform_players(logs)
    columns_matches = GraphMinuteLogsTask.perform_matches(logs)
    columns_matches_start_stop = GraphMinuteLogsTask.perform_matches_start_stop(logs)
    columns_user_connections = GraphMinuteLogsTask.perform_user_connections(logs)
    columns_bot_connections = GraphMinuteLogsTask.perform_bot_connections(logs)
    columns_load = GraphMinuteLogsTask.perform_load(logs)

    conn
    |> assign(:columns_players, columns_players)
    |> assign(:columns_matches, columns_matches)
    |> assign(:columns_matches_start_stop, columns_matches_start_stop)
    |> assign(:columns_user_connections, columns_user_connections)
    |> assign(:columns_bot_connections, columns_bot_connections)
    |> assign(:columns_load, columns_load)
    |> add_breadcrumb(name: "Now", url: conn.request_path)
    |> render("now_graph.html")
  end
end
