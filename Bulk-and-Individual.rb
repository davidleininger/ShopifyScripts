TopSeller = {
  101 => 4,
  76 => 3,
  51 => 2,
  26 => 1,
}

Individual = {
  16 => 3,
  11 => 2,
  6 => 1,
}

PocketGuide = {
  101 => 1,
  76 => 0.75,
  51 => 0.50,
  26 => 0.25,
}

class ItemCampaign
  def initialize(selector, discount)
    @selector = selector
    @discount = discount
  end

  def run(cart)
    # Iterate through the line items in the cart.
    cart.line_items.each do |line_item|
      # Skip this line item unless it's associated with the target product.
      next unless @selector.match?(line_item)

      @discount.apply(line_item)
    end
  end
end

class BulkItemCampaign
  def initialize(bulkList, selector, discount)
    @bulkList = bulkList
    @selector = selector
    @discount = discount
  end

  def run(cart)
    # Iterate through the line items in the cart.
    cart.line_items.each do |line_item|
      # Skip this line item unless it's associated with the target product.
      quantity, discount = @bulkList.find do |quantity, _|
        line_item.quantity >= quantity
      end
      next unless discount
      next unless @selector.match?(line_item)

      @discount.apply(line_item)
    end
  end
end

class AndSelector
  def initialize(*selectors)
    @selectors = selectors
  end

  # Returns whether a line item matches this selector or not.
  def match?(line_item)
    @selectors.all? { |selector| selector.match?(line_item) }
  end
end

class TagSelector
  def initialize(tag)
    @tag = tag
  end

  def match?(line_item)
    line_item.variant.product.tags.include?(@tag)
  end
end

class ExcludeGiftCardSelector
  def match?(line_item)
    !line_item.variant.product.gift_card?
  end
end

class MoneyDiscount

  def initialize(cents, message)
    @amount = Money.new(cents: cents)
    @message = message
  end

  def apply(line_item)
    # Calculate the total discount for this line item
    line_discount = @amount * line_item.quantity

    # Calculated the discounted line price
    new_line_price = line_item.line_price - line_discount

    # Apply the new line price to this line item with a given message describing the discount
    line_item.change_line_price(new_line_price, message: @message)

    # Print a debugging line to the console
    puts "Discounted line item with variant #{line_item.variant.id} by #{line_discount}."
  end
end

class QuantityDiscount

  def initialize(quantityDiscount)
    @discount = quantityDiscount
  end
  
  def apply(line_item)
    # Find quantityDiscount Object - Get Quantity/Discount
    quantity, discount = @discount.find do |quantity, _|
      line_item.quantity >= quantity
    end
    
    # Calculated the discounted line price using the line discount.
    discount_price = line_item.line_price - (Money.new(cents:100) * discount * line_item.quantity)
    
    #Caculate Total Discount
    total_discount = Decimal.new(discount * line_item.quantity) + 0.01
    
    # Set Message.
    message = "$#{discount} off per item when buying more than #{quantity - 1}. You saved $#{total_discount - 0.01}!"

    line_item.change_line_price(discount_price, message: message )
  end
end

# Use an array to keep track of the discount campaigns desired.
CAMPAIGNS = [
  # $2 off all items with the "sale" tag
  ItemCampaign.new(
    AndSelector.new(
      ExcludeGiftCardSelector.new,
      TagSelector.new("sale"),
    ),
    MoneyDiscount.new(2_00, "$2.00 off all items on sale"),
  ),

  # Quantity Breaks for Top Seller
  BulkItemCampaign.new(
    TopSeller,
    AndSelector.new(
      ExcludeGiftCardSelector.new,
      TagSelector.new("Top Seller"),
    ),
    QuantityDiscount.new(TopSeller),
  ),
  
  # Quantity Breaks for Individual
  BulkItemCampaign.new(
    Individual,
    AndSelector.new(
      ExcludeGiftCardSelector.new,
      TagSelector.new("Individual"),
    ),
    QuantityDiscount.new(Individual),
  ),
  
  # Quantity Breaks for Pocket Guides
  BulkItemCampaign.new(
    PocketGuide,
    AndSelector.new(
      ExcludeGiftCardSelector.new,
      TagSelector.new("Pocket Guide"),
    ),
    QuantityDiscount.new(PocketGuide),
  )
]

# Iterate through each of the discount campaigns.
CAMPAIGNS.each do |campaign|
  # Apply the campaign onto the cart.
  campaign.run(Input.cart)
end

# In order to have the changes to the line items be reflected, the output of
# the script needs to be specified.
Output.cart = Input.cart