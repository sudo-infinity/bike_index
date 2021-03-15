module BikeSearchable
  extend ActiveSupport::Concern
  module ClassMethods
    # searchable_interpreted_params returns the args for by all other public methods in this class
    # query_params:
    #   query_items: array of select2 query items. Parsed into query, manufacturer and color
    #   serial: required for search_close_serials
    #   query: full text search string. Overrides query_items if passed explicitly
    #   colors: array of colors, friendly found, faster if integers. Overrides query_items if passed explicitly
    #   manufacturer: friendly found, faster if integer. Overrides query_items if passed explicitly.
    #   stolenness: can be 'all', 'non', 'stolen', 'proximity'. Defaults to 'stolen'
    #   location: location for proximity search. Only for stolenness == 'proximity'. 'ip'/'you' uses IP geocoding and returns location object
    #   distance: distance in miles for matches. Only for stolenness == 'proximity'
    #   bounding_box: bounding box generated by geocoder. Only for stolenness == 'proximity'
    def searchable_interpreted_params(query_params, ip:)
      serial = SerialNormalizer.new(serial: query_params[:serial]) if query_params[:serial].present?
      (serial ? { serial: serial.normalized } : {}) # serial if present
        .merge(searchable_query_items_query(query_params)) # query if present
        .merge(searchable_query_items_manufacturer(query_params)) # manufacturer if present
        .merge(searchable_query_items_colors(query_params)) # color if present
        .merge(searchable_query_stolenness(query_params, ip))
    end

    def search(interpreted_params)
      search_matching_serial(interpreted_params)
        .non_serial_matches(interpreted_params)
    end

    def search_close_serials(interpreted_params)
      return nil unless interpreted_params[:serial]
      # Skip the exact match ids
      where.not(id: search(interpreted_params).pluck(:id))
        .non_serial_matches(interpreted_params)
        .search_matching_close_serials(interpreted_params[:serial])
    end

    # Initial autocomplete options hashes for the main select search input
    # ignores manufacturer_id and color_ids we don't have
    def selected_query_items_options(interpreted_params)
      items = []
      items += [interpreted_params[:query]] if interpreted_params[:query].present?
      items += [interpreted_params[:manufacturer]].flatten.map { |id| Manufacturer.friendly_find(id) }
                 .compact.map(&:autocomplete_result_hash) if interpreted_params[:manufacturer]
      items += interpreted_params[:colors].map { |id| Color.friendly_find(id) }
                 .compact.map(&:autocomplete_result_hash) if interpreted_params[:colors]
      items.flatten.compact
    end

    def permitted_search_params
      [:query, :manufacturer, :location, :distance, :serial, :stolenness, :query_items => [], :colors => []].freeze
    end

    # Private (internal only) methods below here, as defined at the start

    def non_serial_matches(interpreted_params)
      # For each of the of the colors, call searching_matching_color_ids with the color_id on the previous ;)
      (interpreted_params[:colors] || [nil]).reduce(self) { |matches, c_id| matches.search_matching_color_ids(c_id) }
        .search_matching_stolenness(interpreted_params)
        .search_matching_query(interpreted_params[:query])
        .where(interpreted_params[:manufacturer] ? { manufacturer_id: interpreted_params[:manufacturer] } : {})
    end


    def searchable_query_items_query(query_params)
      return { query: query_params[:query] } if query_params[:query].present?
      query = query_params[:query_items] && query_params[:query_items].select { |i| !(/\A[cm]_/ =~ i) }.join(' ')
      query.present? ? { query: query } : {}
    end

    def searchable_query_items_manufacturer(query_params)
      # we expect a singular manufacturer but deal with arrays because the multi-select search
      manufacturer_id = extracted_query_items_manufacturer_id(query_params)
      if manufacturer_id && !manufacturer_id.is_a?(Integer)
        manufacturer_id = [manufacturer_id].flatten.map do |m_id|
          next m_id.to_i if m_id.is_a?(Integer) || m_id.strip =~ /\A\d*\z/
          Manufacturer.friendly_id_find(m_id)
        end.compact
        manufacturer_id = manufacturer_id.first if manufacturer_id.count == 1
      end
      manufacturer_id ? { manufacturer: manufacturer_id } : {}
    end

    def searchable_query_items_colors(query_params)
      color_ids = extracted_query_items_color_ids(query_params)
      if color_ids && !color_ids.is_a?(Integer)
        color_ids = color_ids.map do |c_id|
          next c_id.to_i if c_id.is_a?(Integer) || c_id.strip =~ /\A\d*\z/
          Color.friendly_id_find(c_id)
        end
      end
      color_ids ? { colors: color_ids } : {}
    end

    def searchable_query_stolenness(query_params, ip)
      if query_params[:stolenness] && %w(all non).include?(query_params[:stolenness])
        { stolenness: query_params[:stolenness] }
      else
        pp extracted_searchable_proximity_hash(query_params, ip) || { stolenness: 'stolen' }
        extracted_searchable_proximity_hash(query_params, ip) || { stolenness: 'stolen' }
      end
    end

    def extracted_query_items_manufacturer_id(query_params)
      return query_params[:manufacturer] if query_params[:manufacturer].present?
      manufacturer_id = query_params[:query_items] && query_params[:query_items].select { |i| /\Am_/ =~ i }
      return nil unless manufacturer_id && manufacturer_id.any?
      manufacturer_id.map { |i| i.gsub(/m_/, '').to_i }
    end

    def extracted_query_items_color_ids(query_params)
      return query_params[:colors] if query_params[:colors].present?
      color_ids = query_params[:query_items] && query_params[:query_items].select { |i| /\Ac_/ =~ i }
      return nil unless color_ids && color_ids.any?
      color_ids.map { |i| i.gsub(/c_/, '').to_i }
    end

    def extracted_searchable_proximity_hash(query_params, ip)
      return false unless query_params[:stolenness] == 'proximity'
      location = query_params[:location].present? && query_params[:location]
      return false unless location && !(location =~ /anywhere/i)
      distance = query_params[:distance] && query_params[:distance].to_i
      if location == 'ip' || location == 'you'
        return false unless ip.present?
        location = Geocoder.search(ip)
      end
      bounding_box = Geocoder::Calculations.bounding_box(location, distance)
      return false if bounding_box.detect(&:nan?) # If we can't create a bounding box, skip
      {
        bounding_box: bounding_box,
        stolenness: 'proximity',
        location:  location,
        distance: (distance && distance > 0) ? distance : 100
      }
    end

    # Actual searcher methods
    # The searcher methods return `all` so they can be chained together even if they don't modify anything

    def search_matching_color_ids(color_id)
      return all unless color_id # So we can chain this if we don't have any colors
      where('primary_frame_color_id=? OR secondary_frame_color_id=? OR tertiary_frame_color_id =?', color_id, color_id, color_id)
    end

    def search_matching_query(query)
      query && pg_search(query) || all
    end

    def search_matching_serial(interpreted_params)
      return all unless interpreted_params[:serial]
      # Note: @@ is postgres fulltext search
      where('serial_normalized @@ ?', interpreted_params[:serial])
    end

    def search_matching_stolenness(interpreted_params)
      case interpreted_params[:stolenness]
      when 'all'
        all
      when 'non'
        where(stolen: false)
      when 'proximity'
        where(stolen: true).within_bounding_box(interpreted_params[:bounding_box])
      else
        where(stolen: true)
      end
    end

    def search_matching_close_serials(serial)
      where('LEVENSHTEIN(serial_normalized, ?) < 3', serial)
    end
  end
end
