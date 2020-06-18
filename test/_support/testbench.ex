defmodule TestBench do
  @callback foo() :: atom
end

import Mox

defmock MockBench, for: TestBench
