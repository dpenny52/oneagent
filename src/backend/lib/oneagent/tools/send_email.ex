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
  def required_credential_type, do: nil

  @impl true
  def execute(input, context) do
    from_email = context[:user_email] || "agent@oneagent.ai"

    email =
      Swoosh.Email.new(
        to: input["to"],
        from: {"OneAgent", from_email},
        subject: input["subject"],
        text_body: input["body"]
      )

    case OneAgent.Mailer.deliver(email) do
      {:ok, _} ->
        {:ok, %{"sent_to" => input["to"], "subject" => input["subject"]}}

      {:error, reason} ->
        {:error, "Failed to send email: #{inspect(reason)}"}
    end
  end
end
