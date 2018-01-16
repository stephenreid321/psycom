
namespace :cleanup do
  task :organisations => :environment do
    Organisation.each { |organisation|
      organisation.destroy if organisation.affiliations.count == 0      
    }
  end
  task :sectors => :environment do
    Sector.each { |sector|
      sector.destroy if sector.sectorships.count == 0      
    }
  end  
end
task :cleanup => ['cleanup:organisations', 'cleanup:sectors']

namespace :languages do
  task :default, [:name, :code] => :environment do |t, args|
    Language.create :name => args[:name], :code => args[:code], :default => true
  end 
end

namespace :conversation_posts do
  task :check_for_missing_bccs_and_message_ids => :environment do |t, args|
    ConversationPost.check_for_missing_bccs_and_message_ids
  end 
end
