FactoryGirl.define do
  factory :broker_task, class: Broker::Task do
    sequence(:id)
    name { |n| "Task #{id}" }

    trait :running do
      run_id { "task-#{id}-1-1427988069527-1-mesos.local-DEFAULT" }
    end

    factory :image_build_task do
      build_ref    "b249cc40d802fd93ab0cf1b3395304a0b5baedcd"
      build_secret "762c48ffa3faa0626b50befdd1d690f9"
    end
  end
end