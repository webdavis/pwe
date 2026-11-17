return function(list)
  local total = 0
  for _ in pairs(list) do
    total = total + 1
  end
  return total
end
