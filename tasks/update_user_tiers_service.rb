require "google/cloud/firestore"
require "date"
require "logger"

class UpdateUserTiersService
  def initialize
    @firestore = Google::Cloud::Firestore.new(
      project_id: ENV.fetch("FIRESTORE_PROJECT_ID", "rehuman-marketplace"),
      credentials: ENV.fetch("FIRESTORE_CREDENTIALS", "./rehuman-marketplace-firebase-adminsdk-jo14f-d1895b6515.json")
    )
    @logger = Logger.new(STDOUT)
  end

  def run
    log("Starting Update User Tiers Service...")
    process_users
    log("Update User Tiers Service completed successfully.")
  rescue => e
    log("Error during Update User Tiers Service: #{e.message}", :error)
    log(e.backtrace.join("\n"), :error)
  end

  private

  def process_users
    users = fetch_users
    beginning_of_month = Date.new(Date.today.year, Date.today.month, 1)

    users.each do |user_object|
      begin
        update_user_tier(user_object, beginning_of_month)
      rescue => e
        log("Error processing user #{user_object.document_path}: #{e.message}", :error)
        log(e.backtrace.join("\n"), :error)
      end
    end
  end

  def fetch_users
    @firestore.col("users").run
  end

  def fetch_user_transactions(user_object, beginning_of_month)
    @firestore.col("transaction_history")
             .where(:user_id, "=", user_object.ref)
             .where(:created_at, :">=", beginning_of_month)
             .run
             .map(&:fields)
  end

  def calculate_tier(total_recoins)
    case total_recoins
    when 0...50
      "Bronze"
    when 50...100
      "Silver"
    else
      "Gold"
    end
  end

  def update_user_tier(user_object, beginning_of_month)
    user = user_object.fields
    transactions = fetch_user_transactions(user_object, beginning_of_month)
    total_recoins = transactions.sum { |t| t[:amount] || 0 }

    new_tier = calculate_tier(total_recoins)
    @firestore.doc(user_object.document_path).set({ tier: new_tier }, merge: true)
    log("Updated tier for user #{user_object.document_path} to #{new_tier} (total recoins: #{total_recoins}).")
  end

  def log(message, level = :info)
    @logger.send(level, "[#{Time.now}] #{message}")
  end
end

UpdateUserTiersService.new.run
