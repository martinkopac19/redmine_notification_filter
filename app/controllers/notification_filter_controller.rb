class NotificationFilterController < ApplicationController
  before_action :require_login

  def show
    load_common
    @cfg = stored_config
  end

  def update
    if params[:add_project_id].present?
      cfg = stored_config
      pid = params[:add_project_id].to_s
      cfg['projects'][pid] ||= { 'mode' => 'transitions', 'transitions' => {} }
      save_config(cfg)
      return redirect_to(action: 'show')
    end

    cfg = build_config
    if params[:remove_project_id].present?
      cfg['projects'].delete(params[:remove_project_id].to_s)
      save_config(cfg)
      return redirect_to(action: 'show')
    end

    save_config(cfg)
    flash[:notice] = l(:notice_account_updated)
    redirect_to action: 'show'
  end

  private

  def load_common
    @statuses = IssueStatus.order(:position).to_a
    valid = WorkflowTransition
              .where('old_status_id > 0 AND new_status_id > 0')
              .distinct.pluck(:old_status_id, :new_status_id)
              .map { |o, n| "#{o}:#{n}" }.to_set
    @groups = @statuses.map do |from|
      tos = @statuses.select { |to| valid.include?("#{from.id}:#{to.id}") }
      [from, tos]
    end.reject { |_, tos| tos.empty? }
    @projects = User.current.projects.active.distinct.to_a.sort_by { |p| p.name.downcase }
  end

  def stored_config
    raw = User.current.pref[:notif_filter]
    cfg = raw.is_a?(Hash) ? raw.deep_stringify_keys : {}
    cfg['mode']        ||= 'all'
    cfg['transitions'] ||= {}
    cfg['projects']    ||= {}
    cfg
  end

  def save_config(cfg)
    pref = User.current.pref
    pref[:notif_filter] = cfg
    pref.save
  end

  def build_config
    cfg = {}
    cfg['mode']        = sanitize_mode(params[:mode], allow_inherit: false)
    cfg['transitions'] = parse_transitions(params[:transitions])
    projects = {}
    (params[:projects] || {}).each do |pid, pcfg|
      pcfg = pcfg.respond_to?(:to_unsafe_h) ? pcfg.to_unsafe_h : pcfg
      projects[pid.to_s] = {
        'mode'        => sanitize_mode(pcfg['mode'], allow_inherit: true),
        'transitions' => parse_transitions(pcfg['transitions'])
      }
    end
    cfg['projects'] = projects
    cfg
  end

  def sanitize_mode(val, allow_inherit:)
    allowed = %w[all comments_only transitions]
    allowed << 'inherit' if allow_inherit
    allowed.include?(val) ? val : (allow_inherit ? 'inherit' : 'all')
  end

  def parse_transitions(h)
    h = h.respond_to?(:to_unsafe_h) ? h.to_unsafe_h : h
    out = {}
    (h || {}).each { |k, v| out[k.to_s] = true if v == '1' || v == true }
    out
  end
end
