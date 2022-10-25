defmodule TestBench do
  @moduledoc false

  @callback foo() :: atom
end

import Mox

defmock(MockBench, for: TestBench)
