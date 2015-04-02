FactoryGirl.define do
  factory :gitlab_namespace, class: Hash do
    initialize_with { attributes }

    sequence(:id)
    sequence(:name) { |n| "#{path.capitalize}" }
    sequence(:path) { generate :code_word }
  end

  factory :gitlab_project, class: Hash do
    sequence(:id)
    name { "Project ##{id}" }
    path { "project-#{id}" }
    default_branch 'master'
    association :namespace, factory: :gitlab_namespace, strategy: :build

    initialize_with { attributes }
  end
end
