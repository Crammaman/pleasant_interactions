require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
# require "active_storage/engine"
require "action_controller/railtie"
# require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module PleasantInteractions
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Don't generate system test files.
    config.generators.system_tests = nil

    # Sass is a compiler input, not a servable asset. Without this, Propshaft
    # publishes our .scss sources and the whole of Bulma's Sass tree (~75 files)
    # into public/assets, alongside the CSS dart-sass built from them.
    #
    # Propshaft subtracts excluded_paths from config.assets.paths, and that is
    # the same list dartsass-rails derives Sass's --load-path from, so Bulma's
    # directory has to be handed to the compiler explicitly. Our own stylesheet
    # directory needs no such treatment: dartsass-rails always looks there.
    bulma_sass_path = Gem.loaded_specs["bulma-rails"].gem_dir + "/app/assets/stylesheets"

    config.assets.excluded_paths << Rails.root.join("app/assets/stylesheets")
    config.assets.excluded_paths << bulma_sass_path
    config.dartsass.build_options += [ "--load-path", bulma_sass_path ]
  end
end
