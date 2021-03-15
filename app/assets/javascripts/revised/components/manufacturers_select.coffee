class BikeIndex.ManufacturersSelect extends BikeIndex
  per_page =
    10
  constructor: (target_selector, frame_mnfg = true) ->
    $target = $(target_selector)
    return true unless $target.hasClass('unfancy')
    initial_opts = if $target.data('initial') then [$target.data('initial')] else []
    if frame_mnfg
      @makeFrameManufacturer($target, initial_opts)
    else
      @makeComponentManufacturer($target, initial_opts)

  selectizeSettings: (url, initial_opts) ->
    plugins: ['restore_on_backspace']
    options: initial_opts
    persist: false
    create: false
    maxItems: 1
    selectOnTab: true
    valueField: 'slug' # for convenience in viewing, also functionality without JS. Overridden in components
    labelField: 'text'
    searchField: 'text'
    loadThrottle: 130
    score: (search) ->
      score = this.getScoreFunction(search)
      return (item) ->
        score(item) * (1 + Math.min(item.priority / 100, 1))
    load: (query, callback) ->
      $.ajax
        url: "#{url}#{encodeURIComponent(query)}"
        type: 'GET'
        error: ->
          callback()
        success: (res) ->
          callback res.matches.slice(0, @per_page)

  makeFrameManufacturer: ($target, initial_opts) ->
    url = "#{window.root_url}/api/autocomplete?per_page=#{per_page}&categories=frame_mnfg&q="
    $target.selectize(@selectizeSettings(url, initial_opts))
    $target.removeClass('unfancy') # So we don't instantiate multiple times

  makeComponentManufacturer: ($target, initial_opts) ->
    url = "#{window.root_url}/api/autocomplete?per_page=#{per_page}&categories=frame_mnfg,mnfg&q="
    component_selectize_opts = 
      valueField: 'id' # for convenience instantiating, overrides frameManufacturer
    opts = _.merge(@selectizeSettings(url, initial_opts), component_selectize_opts)
    $target.selectize(opts)
    $target.removeClass('unfancy') # So we don't instantiate multiple times
