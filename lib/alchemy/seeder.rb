require 'yaml'

module Alchemy
	class Seeder

		# This seed builds the necessary page structure for alchemy in your db.
		# Put Alchemy::Seeder.seed! inside your db/seeds.rb file and run it with rake db:seed.
		def self.seed!
			errors = []
			notices = []
			
			default_language = Alchemy::Config.get(:default_language)
			
			lang = Language.find_or_initialize_by_code(
				:name => default_language['name'],
				:code => default_language['code'],
				:frontpage_name => default_language['frontpage_name'],
				:page_layout => default_language['page_layout'],
				:public => true,
				:default => true
			)
			if lang.new_record?
				if lang.save
					puts "== Created language #{lang.name}"
				else
					errors << "Errors creating language #{lang.name}: #{lang.errors.full_messages}"
				end
			else
				notices << "== Skipping! Language #{lang.name} was already present"
			end
			
			root = Page.find_or_initialize_by_name(
				:name => 'Root',
				:page_layout => "rootpage",
				:do_not_autogenerate => true,
				:do_not_sweep => true,
				:language => lang
			)
			if root.new_record?
				if root.save
					# We have to remove the language, because active record validates its presence on create.
					root.language = nil
					root.save
					puts "== Created page #{root.name}"
				else
					errors << "Errors creating page #{root.name}: #{root.errors.full_messages}"
				end
			else
				notices << "== Skipping! Page #{root.name} was already present"
			end
			
			if errors.blank?
				puts "Success!"
				notices.map{ |note| puts note }
			else
				puts "WARNING! Some pages could not be created:"
				errors.map{ |error| puts error }
			end
		end

		# This method is for running after upgrading an old Alchemy version without Language Model (pre v1.5).
		# Put Alchemy::Seeder.upgrade! inside your db/seeds.rb file and run it with rake db:seed.
		def self.upgrade!
			seed!
			Page.all.each do |page|
				if !page.language_code.blank? && page.language.nil?
					root = page.get_language_root
					lang = Language.find_or_create_by_code(
						:name => page.language_code.capitalize,
						:code => page.language_code,
						:frontpage_name => root.name,
						:page_layout => root.page_layout,
						:public => true
					)
					page.language = lang
					if page.save(:validate => false)
						puts "== Set language for page #{page.name} to #{lang.name}"
					end
				else
					puts "== Skipping! Language for page #{page.name} already set."
				end
			end
			default_language = Language.get_default
			Page.layoutpages.each do |page|
				if page.language.class == String || page.language.nil?
					page.language = default_language
					if page.save(:validate => false)
						puts "== Set language for page #{page.name} to #{default_language.name}"
					end
				else
					puts "== Skipping! Language for page #{page.name} already set."
				end
			end
			(EssencePicture.all + EssenceText.all).each do |essence|
				case essence.link_target
				when '1'
					if essence.update_attribute(:link_target, 'blank')
						puts "== Updated #{essence.preview_text} link target to #{essence.link_target}."
					end
				when '0'
					essence.update_attribute(:link_target, nil)
					puts "== Updated #{essence.preview_text} link target to #{essence.link_target.inspect}."
				end
			end
		end

	end
end
