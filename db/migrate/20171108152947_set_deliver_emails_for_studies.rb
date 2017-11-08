# set default deliver emails flag for studies
class SetDeliverEmailsForStudies < Mongoid::Migration
  def self.up
    Study.all.each do |study|
      opts = study.default_options
      study.update!(default_options: opts.merge(deliver_emails: true))
    end
  end

  def self.down
    Study.all.each do |study|
      opts = study.default_options
      opts.delete(:deliver_emails)
      study.update!(default_options: opts)
    end
  end
end