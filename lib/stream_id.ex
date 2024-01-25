defmodule Pine.StreamID do
  defstruct category: nil, id_element: nil

  def gen(category, id_element) do
    %__MODULE__{category: category,
                id_element: id_element}
    
  end

  def to_string(%__MODULE__{category: cat, id_element: id_elem})
  do
    id = Map.get(id_elem, :id)
    "#{cat}-#{id}"
  end
  

end
