def cartHasInvoice?
  for item in Input.cart.line_items
    product = item.variant.product
    if  product.tags.include?('invoice')
      return true
    end
  end
  return false
end

Output.payment_gateways = Input.payment_gateways.delete_if do |payment_gateway|
  if !(cartHasBillParish? || cartHasSupport?)
    payment_gateway.name == "Send Invoice"
  end
end