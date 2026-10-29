defmodule WorkerBee.ValidationRulesTest do
  use ExUnit.Case, async: true

  alias WorkerBee.Validation.{
    BoundaryRules,
    DataRules,
    FunctionalCoreRules,
    LifecycleRules,
    TestingRules
  }

  describe "FunctionalCoreRules" do
    test "failure: a GenServer call in the functional core is a purity error" do
      content = """
      defmodule Cart do
        def add(cart, item), do: GenServer.call(cart, {:add, item})
      end
      """

      assert FunctionalCoreRules.validate_purity(content, "lib/cart.ex") == [
               %{
                 type: :side_effect,
                 severity: :error,
                 line: nil,
                 message: "Functional core should not contain GenServer/Agent/Task operations",
                 rule: "functional_core_purity",
                 file: "lib/cart.ex"
               }
             ]
    end

    test "success: a pure module with tagged returns has no violations" do
      content = """
      defmodule Pricing do
        @spec total([map()]) :: {:ok, number()}
        def total(items), do: {:ok, Enum.reduce(items, 0, &(&1.price + &2))}
      end
      """

      assert FunctionalCoreRules.validate(content, "lib/pricing.ex") == []
    end

    test "failure: complexity is scored from the function body, at the def line" do
      branches = Enum.map_join(1..10, "\n", &"    if x == #{&1}, do: #{&1}")

      content = """
      defmodule Rules do
        def classify(x) do
      #{branches}
        end
      end
      """

      assert FunctionalCoreRules.validate_single_responsibility(content, "lib/rules.ex") == [
               %{
                 type: :high_complexity,
                 severity: :warning,
                 line: 2,
                 message: "Function 'classify' is too complex (score: 11)",
                 rule: "function_complexity",
                 file: "lib/rules.ex"
               }
             ]
    end
  end

  describe "BoundaryRules" do
    test "failure: a GenServer without init/1 is a structure error" do
      content = """
      defmodule Counter do
        use GenServer
        @type state :: integer()
        def handle_call(:get, _from, count), do: {:reply, count, count}
      end
      """

      assert BoundaryRules.validate_genserver_patterns(content, "lib/counter.ex") == [
               %{
                 type: :missing_callback,
                 severity: :error,
                 line: nil,
                 message: "GenServer must implement init/1 callback",
                 rule: "genserver_structure",
                 file: "lib/counter.ex"
               }
             ]
    end

    test "failure: a with expression without else is reported at its line" do
      content = """
      defmodule Accounts do
        def register(params) do
          with {:ok, user} <- build(params) do
            {:ok, user}
          end
        end
      end
      """

      assert BoundaryRules.validate_error_handling(content, "lib/accounts.ex") == [
               %{
                 type: :missing_error_handling,
                 severity: :warning,
                 line: 3,
                 message: "'with' statement should have 'else' clause for error handling",
                 rule: "error_propagation",
                 file: "lib/accounts.ex"
               }
             ]
    end

    test "success: a with expression with an else clause passes" do
      content = """
      defmodule Accounts do
        def register(params) do
          with {:ok, user} <- build(params) do
            {:ok, user}
          else
            {:error, reason} -> {:error, reason}
          end
        end
      end
      """

      assert BoundaryRules.validate_error_handling(content, "lib/accounts.ex") == []
    end

    test "failure: an unparseable file is reported, not skipped" do
      content = """
      defmodule Broken do
        def oops(
      end
      """

      assert [%{type: :unparseable_file, severity: :warning, rule: "error_propagation"}] =
               BoundaryRules.validate_error_handling(content, "lib/broken.ex")
    end
  end

  describe "DataRules" do
    test "failure: Map.put on a struct suggests update syntax" do
      content = """
      defmodule Order do
        defstruct status: :new, total: 0
        def mark_paid(order), do: Map.put(order, :status, :paid)
      end
      """

      assert DataRules.validate(content, "lib/order.ex") == [
               %{
                 type: :data_mutation,
                 severity: :info,
                 line: nil,
                 message: "Consider using struct update syntax: %{struct | field: value}",
                 rule: "immutability_patterns",
                 file: "lib/order.ex"
               }
             ]
    end
  end

  describe "TestingRules" do
    test "failure: a short test name is reported at its line" do
      content = """
      defmodule OrderTest do
        use ExUnit.Case, async: true
        describe "mark_paid/1" do
          test "works" do
            assert Order.mark_paid(%Order{}).status == :paid
          end
        end
      end
      """

      assert TestingRules.validate(content, "test/order_test.exs") == [
               %{
                 type: :poor_test_naming,
                 severity: :info,
                 line: 4,
                 message: "Test name 'works' should be more descriptive",
                 rule: "test_naming",
                 file: "test/order_test.exs"
               }
             ]
    end
  end

  describe "LifecycleRules" do
    test "failure: an Application without start/2 is an error" do
      content = """
      defmodule Shop.Application do
        use Application
      end
      """

      assert LifecycleRules.validate(content, "lib/shop/application.ex") == [
               %{
                 type: :missing_start_function,
                 severity: :error,
                 line: nil,
                 message: "Application must implement start/2 function",
                 rule: "application_structure",
                 file: "lib/shop/application.ex"
               }
             ]
    end
  end
end
