# rubocop:disable Metrics/ModuleLength
module Webui::WebuiHelper
  include ActionView::Helpers::JavaScriptHelper
  include ActionView::Helpers::AssetTagHelper
  include Webui::BuildresultHelper

  def bugzilla_url(email_list = '', desc = '')
    return '' if @configuration['bugzilla_url'].blank?
    assignee = email_list.first if email_list
    if email_list.length > 1
      cc = ('&cc=' + email_list[1..-1].join('&cc=')) if email_list
    end

    URI.escape(
      "#{@configuration['bugzilla_url']}/enter_bug.cgi?classification=7340&product=openSUSE.org" \
      "&component=3rd party software&assigned_to=#{assignee}#{cc}&short_desc=#{desc}"
    )
  end

  def fuzzy_time(time, with_fulltime = true)
    if Time.now - time < 60
      return 'now' # rails' 'less than a minute' is a bit long
    end

    human_time_ago = time_ago_in_words(time) + ' ago'

    if with_fulltime
      raw("<span title='#{l(time.utc)}' class='fuzzy-time'>#{human_time_ago}</span>")
    else
      human_time_ago
    end
  end

  def fuzzy_time_string(timestring)
    fuzzy_time(Time.parse(timestring), false)
  end

  def format_projectname(prjname, login)
    splitted = prjname.split(':', 3)
    if splitted[0] == 'home'
      if login && splitted[1] == login
        prjname = '~'
      else
        prjname = "~#{splitted[1]}"
      end
      prjname += ":#{splitted[-1]}" if splitted.length > 2
    end
    prjname
  end

  # TODO: bento_only
  REPO_STATUS_ICONS = {
    'published' => 'lorry',
    'publishing' => 'cog_go',
    'outdated_published' => 'lorry_error',
    'outdated_publishing' => 'cog_error',
    'unpublished' => 'lorry_flatbed',
    'outdated_unpublished' => 'lorry_error',
    'building' => 'cog',
    'outdated_building' => 'cog_error',
    'finished' => 'time',
    'outdated_finished' => 'time_error',
    'blocked' => 'time',
    'outdated_blocked' => 'time_error',
    'broken' => 'exclamation',
    'outdated_broken' => 'exclamation',
    'scheduling' => 'cog',
    'outdated_scheduling' => 'cog_error'
  }.freeze

  WEBUI2_REPO_STATUS_ICONS = {
    'published' => 'truck',
    'outdated_published' => 'truck',
    'publishing' => 'truck-loading',
    'outdated_publishing' => 'truck-loading',
    'unpublished' => 'dolly-flatbed',
    'outdated_unpublished' => 'dolly-flatbed',
    'building' => 'cog',
    'outdated_building' => 'cog',
    'finished' => 'check',
    'outdated_finished' => 'check',
    'blocked' => 'lock',
    'outdated_blocked' => 'lock',
    'broken' => 'exclamation-triangle',
    'outdated_broken' => 'exclamation-triangle',
    'scheduling' => 'calendar-alt',
    'outdated_scheduling' => 'calendar-alt'
  }.freeze

  REPO_STATUS_DESCRIPTIONS = {
    'published' => 'Repository has been published',
    'publishing' => 'Repository is being created right now',
    'unpublished' => 'Build finished, but repository publishing is disabled',
    'building' => 'Build jobs exists',
    'finished' => 'Build jobs have been processed, new repository is not yet created',
    'blocked' => 'No build possible atm, waiting for jobs in other repositories',
    'broken' => 'The repository setup is broken, build or publish not possible',
    'scheduling' => 'The repository state is being calculated right now'
  }.freeze

  def repo_status_description(status)
    REPO_STATUS_DESCRIPTIONS[status] || 'Unknown state of repository'
  end

  def webui2_repo_status_icon(status)
    WEBUI2_REPO_STATUS_ICONS[status] || 'eye'
  end

  def check_first(first)
    first.nil? ? true : nil
  end

  def image_template_icon(template)
    default_icon = image_url('icons/drive-optical-48.png')
    icon = template.public_source_path('_icon') if template.has_icon?
    capture_haml do
      haml_tag(:object, data: icon || default_icon, type: 'image/png', title: template.title, width: 32, height: 32) do
        haml_tag(:img, src: default_icon, alt: template.title, width: 32, height: 32)
      end
    end
  end

  # TODO: bento_only
  def repo_status_icon(status, details = nil)
    icon = REPO_STATUS_ICONS[status] || 'eye'
    outdated = nil
    if /^outdated_/.match?(status)
      status.gsub!(%r{^outdated_}, '')
      outdated = true
    end

    description = REPO_STATUS_DESCRIPTIONS[status] || 'Unknown state of repository'
    description = 'State needs recalculations, former state was: ' + description if outdated
    description += ' (' + details + ')' if details

    sprite_tag icon, title: description
  end

  def webui2_repository_status_icon(status:, details: nil, html_class: '')
    outdated = status.start_with?('outdated_')
    status = status.sub('outdated_', '')
    description = outdated ? 'State needs recalculations, former state was: ' : ''
    description << repo_status_description(status)
    description << " (#{details})" if details

    repo_state_class = webui2_repository_state_class(outdated, status)

    content_tag(:i, '', class: "repository-state-#{repo_state_class} #{html_class} fas fa-#{webui2_repo_status_icon(status)}",
                        data: { content: description, placement: 'top', toggle: 'popover' })
  end

  def webui2_repository_state_class(outdated, status)
    return 'outdated' if outdated
    return status =~ /broken|building|finished|publishing|published/ ? status : 'default'
  end

  # TODO: bento_only
  def tab(id, text, opts)
    opts[:package] = @package.to_s if @package
    if @project
      if opts[:controller].to_s.ends_with?('pulse', 'meta', 'maintenance_incidents')
        opts[:project_name] = @project.name
      else
        opts[:project] = @project.to_s
      end
    end
    link_opts = { id: "tab-#{id}" }

    if (action_name == opts[:action].to_s && opts[:controller].to_s.ends_with?(controller_name)) || opts[:selected]
      link_opts[:class] = 'selected'
    end
    content_tag('li', link_to(h(text), opts), link_opts)
  end

  # Shortens a text if it longer than 'length'.
  def elide(text, length = 20, mode = :middle)
    shortened_text = text.to_s # make sure it's a String

    return '' if text.blank?

    return '...' if length <= 3 # corner case

    if text.length > length
      case mode
      when :left # shorten at the beginning
        shortened_text = '...' + text[text.length - length + 3..text.length]
      when :middle # shorten in the middle
        pre = text[0..length / 2 - 2]
        offset = 2 # depends if (shortened) length is even or odd
        offset = 1 if length.odd?
        post = text[text.length - length / 2 + offset..text.length]
        shortened_text = pre + '...' + post
      when :right # shorten at the end
        shortened_text = text[0..length - 4] + '...'
      end
    end
    shortened_text
  end

  def elide_two(text1, text2, overall_length = 40, mode = :middle)
    half_length = overall_length / 2
    text1_free = half_length - text1.to_s.length
    text1_free = 0 if text1_free < 0
    text2_free = half_length - text2.to_s.length
    text2_free = 0 if text2_free < 0
    [elide(text1, half_length + text2_free, mode), elide(text2, half_length + text1_free, mode)]
  end

  def force_utf8_and_transform_nonprintables(text)
    return '' if text.blank?
    text.force_encoding('UTF-8')
    unless text.valid_encoding?
      text = 'The file you look at is not valid UTF-8 text. Please convert the file.'
    end
    # Ged rid of stuff that shouldn't be part of PCDATA:
    text.gsub(/([^a-zA-Z0-9&;<>\/\n \t()])/) do
      if Regexp.last_match(1)[0].getbyte(0) < 32
        ''
      else
        Regexp.last_match(1)
      end
    end
  end

  # TODO: bento_only
  def description_wrapper(description)
    if description.blank?
      content_tag(:p, id: 'description-text') do
        content_tag(:i, 'No description set')
      end
    else
      content_tag(:pre, description, id: 'description-text', class: 'plain')
    end
  end

  # TODO: bento_only
  def is_advanced_tab?
    action_name.in?(['index', 'status']) || controller_name.in?(['project_configuration', 'meta', 'pulse'])
  end

  def sprite_tag(icon, opts = {})
    if opts.key?(:class)
      opts[:class] += " icons-#{icon}"
    else
      opts[:class] = "icons-#{icon}"
    end
    unless opts.key?(:alt)
      alt = icon
      if opts[:title]
        alt = opts[:title]
      else
        Rails.logger.warn 'No alt/title text for sprite_tag'
      end
      opts[:alt] = alt
    end
    image_tag('s.gif', opts)
  end

  def sprited_text(icon, text)
    sprite_tag(icon, title: text) + ' ' + text
  end

  def next_codemirror_uid
    return @codemirror_editor_setup = 0 unless @codemirror_editor_setup
    @codemirror_editor_setup += 1
  end

  def codemirror_style(opts = {})
    opts.reverse_merge!(read_only: false, no_border: false, width: 'auto', height: 'auto')

    style = ".CodeMirror {\n"
    style += "border-width: 0 0 0 0;\n" if opts[:no_border] || opts[:read_only]
    style += "height: #{opts[:height]};\n" unless opts[:height] == 'auto'
    style += "width: #{opts[:width]}; \n" unless opts[:width] == 'auto'
    style + "}\n"
  end

  def remove_dialog_tag(text)
    link_to(text, '#', title: 'Close', id: 'remove_dialog', class: 'close-dialog')
  end

  def package_link(pack, opts = {})
    opts[:project] = pack.project.name
    opts[:package] = pack.name
    project_or_package_link(opts)
  end

  def link_to_package(prj, pkg, opts)
    opts[:project_text] ||= opts[:project]
    opts[:package_text] ||= opts[:package]

    unless opts[:trim_to].nil?
      opts[:project_text], opts[:package_text] =
        elide_two(opts[:project_text], opts[:package_text], opts[:trim_to])
    end

    if opts[:short]
      out = ''.html_safe
    else
      out = 'package '.html_safe
    end

    opts[:short] = true # for project
    out += link_to_project(prj, opts) + ' / ' +
           link_to_if(pkg, opts[:package_text],
                      { controller: '/webui/package', action: 'show',
                        project: opts[:project],
                        package: opts[:package] }, class: 'package', title: opts[:package])
    if opts[:rev] && pkg
      out += ' ('.html_safe +
             link_to("revision #{elide(opts[:rev], 10)}",
                     { controller: '/webui/package', action: 'show',
                       project: opts[:project], package: opts[:package], rev: opts[:rev] },
                     class: 'package', title: opts[:rev]) + ')'.html_safe
    end
    out
  end

  def link_to_project(prj, opts)
    opts[:project_text] ||= opts[:project]
    if opts[:short]
      out = ''.html_safe
    else
      out = 'project '.html_safe
    end
    project_text = opts[:trim_to].nil? ? opts[:project_text] : elide(opts[:project_text], opts[:trim_to])
    out + link_to_if(prj, project_text,
                     { controller: '/webui/project', action: 'show', project: opts[:project] },
                     class: 'project', title: opts[:project])
  end

  def project_or_package_link(opts)
    defaults = { package: nil, rev: nil, short: false, trim_to: 40 }
    opts = defaults.merge(opts)

    # only care for database entries
    prj = Project.where(name: opts[:project]).select(:id, :name, :updated_at).first
    # Expires in 2 hours so that changes of local and remote packages eventually result in an update
    Rails.cache.fetch(['project_or_package_link', prj.try(:id), opts], expires_in: 2.hours) do
      if prj && opts[:creator]
        opts[:project_text] ||= format_projectname(opts[:project], opts[:creator])
      end
      if opts[:package] && prj && opts[:package] != :multiple
        pkg = prj.packages.where(name: opts[:package]).select(:id, :name, :project_id).first
      end
      if opts[:package]
        link_to_package(prj, pkg, opts)
      else
        link_to_project(prj, opts)
      end
    end
  end

  def creator_intentions(role = nil)
    role.blank? ? 'become bugowner (previous bugowners will be deleted)' : "get the role #{role}"
  end

  # If there is any content add the ul tag
  def possibly_empty_ul(html_opts, &block)
    content = capture(&block)
    if content.blank?
      html_opts[:fallback]
    else
      html_opts.delete :fallback
      content_tag(:ul, content, html_opts)
    end
  end

  def can_register
    return false if CONFIG['kerberos_mode']
    return true if User.admin_session?

    begin
      UnregisteredUser.can_register?
    rescue APIError
      return false
    end
    true
  end

  def escape_nested_list(list)
    # The input list is not html_safe because it's
    # user input which we should never trust!!!
    list.map do |item|
      "['".html_safe +
        escape_javascript(item[0]) +
        "', '".html_safe +
        escape_javascript(item[1]) +
        "']".html_safe
    end.join(",\n").html_safe
  end

  def replace_jquery_meta_characters(input)
    # The stated characters are c&p from https://api.jquery.com/category/selectors/
    input.gsub(/[!"#$%&'()*+,.\/:\\;<=>?@\[\]^`{|}~]/, '_')
  end

  def word_break(string, length = 80)
    return '' unless string
    # adds a <wbr> tag after an amount of given characters
    safe_join(string.scan(/.{1,#{length}}/), '<wbr>'.html_safe)
  end

  def toggle_sliced_text(text, slice_length = 50, id = "toggle_sliced_text_#{Time.now.to_f.to_s.delete('.')}")
    return text if text.to_s.length < slice_length
    javascript_toggle_code = "$(\"[data-toggle-id='".html_safe + id + "']\").toggle();".html_safe
    short = content_tag(:span, 'data-toggle-id' => id) do
      content_tag(:span, text.slice(0, slice_length) + ' ') +
        link_to('[+]', 'javascript:void(0)', onclick: javascript_toggle_code)
    end
    long = content_tag(:span, 'data-toggle-id' => id, :style => 'display: none;') do
      content_tag(:span, text + ' ') +
        link_to('[-]', 'javascript:void(0)', onclick: javascript_toggle_code)
    end
    short + long
  end

  def tab_link(label, path, active = false, permit = true)
    html_class = 'nav-link text-nowrap'
    html_class << ' active' if active || (request.path.include?(path) && permit)

    link_to(label, path, class: html_class)
  end

  def image_tag_for(object, size: 500, custom_class: 'img-fluid')
    return unless object
    alt = "#{object.name}'s avatar"
    image_tag(gravatar_icon(object.email, size), alt: alt, size: size, title: object.name, class: custom_class)
  end

  def gravatar_icon(email, size)
    if ::Configuration.gravatar && email
      "https://www.gravatar.com/avatar/#{Digest::MD5.hexdigest(email.downcase)}?s=#{size}&d=wavatar"
    else
      'default_face.png'
    end
  end

  def home_title
    @configuration ? @configuration['title'] : 'Open Build Service'
  end
end
# rubocop:enable Metrics/ModuleLength
