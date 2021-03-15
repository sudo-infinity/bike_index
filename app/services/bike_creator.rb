class BikeCreatorError < StandardError
end

class BikeCreator
  def initialize(b_param = nil)
    @b_param = b_param
    @bike = nil
  end

  def add_bike_book_data
    return nil unless @b_param.present? && @b_param.params.present? && @b_param.params[:bike].present?
    return nil unless @b_param.bike[:manufacturer_id].present?
    return nil unless @b_param.bike[:frame_model].present?
    return nil unless @b_param.bike[:year].present?
    bike = {
      manufacturer: Manufacturer.find(@b_param.bike[:manufacturer_id]).name,
      year: @b_param.bike[:year],
      frame_model: @b_param.bike[:frame_model]
    }
    return nil unless bb_data = BikeBookIntegration.new.get_model(bike).with_indifferent_access
    @b_param.params[:bike][:cycle_type] = bb_data[:bike][:cycle_type] if bb_data[:bike][:cycle_type].present?
    @b_param.params[:bike][:paint_name] = bb_data[:bike][:paint_description] if bb_data[:bike][:paint_description].present?
    @b_param.params[:bike][:description] = bb_data[:bike][:description] if bb_data[:bike][:description].present?
    @b_param.params[:bike][:wheel_size] = bb_data[:bike][:wheel_size] if bb_data[:bike][:wheel_size].present?
    @b_param.params[:bike][:stock_photo_url] = bb_data[:bike][:stock_photo_url] if bb_data[:bike][:stock_photo_url].present?
    @b_param.params[:components] = bb_data[:components]
    @b_param.save
  end

  def build_new_bike
    @bike = BikeCreatorBuilder.new(@b_param).build_new
  end

  def build_bike
    @bike = BikeCreatorBuilder.new(@b_param).build 
  end

  def create_associations(bike)
    @bike = BikeCreatorAssociator.new(@b_param).associate(bike)
  end

  def set_normalized_serial
    SerialNormalizer.new({bike_id: @b_param.created_bike_id}).set_normalized
  end

  def clear_bike(bike)
    build_bike
    bike.errors.messages.each do |message|
      @bike.errors.add(message[0], message[1][0])
    end
    bike.destroy
    @bike
  end

  # def associate_picture_with_params
  #   # I think this might be required, check it
  #   # BikeCreatorAssociator.new(@b_param).associate_picture(@b_param)
  # end

  def validate_record(bike)
    if bike.errors.present?
      clear_bike(bike)
    elsif @b_param.created_bike.present?
      bike.destroy
      @bike = @b_param.created_bike
    else
      @b_param.update_attributes(created_bike_id: bike.id, bike_errors: nil)
      set_normalized_serial
    end
    @bike 
  end

  def save_bike(bike)
    bike.save
    @bike = create_associations(bike)
    validate_record(@bike)
    @bike
  end

  def new_bike
    @bike = build_new_bike
    @bike
  end

  def create_bike
    add_bike_book_data
    @bike = build_bike
    return @bike if @bike.errors.present?
    return @bike if @bike.payment_required
    save_bike(@bike)
  end

  def create_paid_bike
    add_bike_book_data
    @bike = build_bike
    @bike.payment_required = false
    @bike.verified = true
    @bike.paid_for = true
    save_bike(@bike)
  end

end