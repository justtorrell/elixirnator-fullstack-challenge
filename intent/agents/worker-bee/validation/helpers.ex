defmodule WorkerBee.Validation.Helpers do
  @moduledoc """
  Shared building blocks for the WDD validation rule modules.

  Every check in a rule module returns a list of violations (empty when the
  check passes), so a layer's checks compose with `run_checks/3`.
  """

  @type severity :: :error | :warning | :info

  @type violation :: %{
          type: atom(),
          severity: severity(),
          line: pos_integer() | nil,
          message: String.t(),
          rule: String.t(),
          file: String.t()
        }

  @type check :: (String.t(), String.t() -> [violation()])

  # A line that starts a new definition or a module attribute ends the body
  # of the function above it.
  @body_boundary ~r/^\s*(defp?|defmacrop?|@\w+)\s/

  @doc """
  Runs each check against the content and concatenates their violations.
  """
  @spec run_checks([check()], String.t(), String.t()) :: [violation()]
  def run_checks(checks, content, file_path) do
    Enum.flat_map(checks, & &1.(content, file_path))
  end

  @doc """
  Builds a violation map.
  """
  @spec violation(atom(), severity(), pos_integer() | nil, String.t(), String.t(), String.t()) ::
          violation()
  def violation(type, severity, line, message, rule, file_path) do
    %{type: type, severity: severity, line: line, message: message, rule: rule, file: file_path}
  end

  @doc """
  Returns `[violation]` when the condition holds, `[]` otherwise.
  """
  @spec flag_if(boolean(), violation()) :: [violation()]
  def flag_if(true, violation), do: [violation]
  def flag_if(false, _violation), do: []

  @doc """
  Public function clauses as `{name, body, line}`.

  The body runs from the `def` line up to the next definition or module
  attribute, which is a line-based approximation of the clause.
  """
  @spec function_definitions(String.t()) :: [{String.t(), String.t(), pos_integer()}]
  def function_definitions(content) do
    lines = String.split(content, "\n")
    boundaries = boundary_lines(lines)

    lines
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {line, line_num} ->
      case Regex.run(~r/^\s*def\s+(\w+[?!]?)/, line) do
        [_, name] -> [{name, function_body(lines, line_num, boundaries), line_num}]
        nil -> []
      end
    end)
  end

  @doc """
  A rough cyclomatic score: one plus each branching construct.
  """
  @spec complexity(String.t()) :: pos_integer()
  def complexity(code) do
    1 + length(Regex.scan(~r/\b(if|case|cond|with)\s/, code))
  end

  @doc """
  The 1-based line number of a byte offset into the content.
  """
  @spec line_at(String.t(), non_neg_integer()) :: pos_integer()
  def line_at(content, offset) do
    content
    |> binary_part(0, offset)
    |> String.split("\n")
    |> length()
  end

  defp boundary_lines(lines) do
    lines
    |> Enum.with_index(1)
    |> Enum.filter(fn {line, _line_num} -> Regex.match?(@body_boundary, line) end)
    |> Enum.map(fn {_line, line_num} -> line_num end)
  end

  defp function_body(lines, line_num, boundaries) do
    stop = Enum.find(boundaries, length(lines) + 1, &(&1 > line_num))

    lines
    |> Enum.slice((line_num - 1)..(stop - 2)//1)
    |> Enum.join("\n")
  end
end
