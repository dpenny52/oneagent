defmodule OneAgent.Tools.SendEmail do
  @moduledoc """
  Sends an email on behalf of the user. Requires `email` bucket.
  """

  @behaviour OneAgent.Tools.Tool

  @impl true
  def id, do: "send_email"

  @impl true
  def name, do: "Send Email"

  @impl true
  def description do
    "Send an email to a recipient. Requires email permission."
  end

  @impl true
  def bucket, do: :email

  @impl true
  def parameters_schema do
    %{
      "type" => "object",
      "properties" => %{
        "to" => %{
          "type" => "string",
          "description" => "Recipient email address"
        },
        "subject" => %{
          "type" => "string",
          "description" => "Email subject line"
        },
        "body" => %{
          "type" => "string",
          "description" => "Email body (plain text)"
        }
      },
      "required" => ["to", "subject", "body"]
    }
  end

  @impl true
  def required_credential_type, do: :api_key

  # Same pattern used in User.validate_email — no spaces, commas, or semicolons
  @email_regex ~r/^[^@,;\s]+@[^@,;\s]+$/

  @max_subject_length 998
  @max_body_length 100_000

  @impl true
  def execute(input, context) do
    to = input["to"]
    subject = input["subject"]
    body = input["body"]

    cond do
      !is_binary(to) or to == "" ->
        {:error, "Missing required parameter: to (recipient email address)"}

      String.length(to) > 254 ->
        {:error, "Invalid recipient email: address too long (max 254 characters)"}

      not Regex.match?(@email_regex, to) ->
        {:error, "Invalid recipient email: must be a valid email address with no spaces, commas, or semicolons"}

      !is_binary(subject) or String.trim(subject) == "" ->
        {:error, "Missing required parameter: subject (email subject line)"}

      String.length(subject) > @max_subject_length ->
        {:error, "Subject too long (max #{@max_subject_length} characters)"}

      !is_binary(body) or String.trim(body) == "" ->
        {:error, "Missing required parameter: body (email body text)"}

      String.length(body) > @max_body_length ->
        {:error, "Body too long (max #{@max_body_length} characters)"}

      true ->
        do_send(input, context)
    end
  end

  defp do_send(input, context) do
    from_email = Application.get_env(:oneagent, :email_from, "onboarding@resend.dev")

    email =
      Swoosh.Email.new(
        to: input["to"],
        from: {"OneAgent", from_email},
        subject: input["subject"],
        text_body: input["body"]
      )

    # Pass credential as Resend API key override if available
    deliver_config =
      case context[:credential_value] do
        nil -> []
        api_key -> [api_key: api_key]
      end

    case OneAgent.Mailer.deliver(email, deliver_config) do
      {:ok, _} ->
        {:ok, %{"sent_to" => input["to"], "subject" => input["subject"]}}

      {:error, reason} ->
        {:error, "Failed to send email: #{inspect(reason)}"}
    end
  end
end
