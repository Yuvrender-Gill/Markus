require File.join(File.dirname(__FILE__), '..', '..', 'test_helper')
require File.join(File.dirname(__FILE__), '..', '..', 'blueprints', 'blueprints')
require File.join(File.dirname(__FILE__), '..', '..', 'blueprints', 'helper')
require 'shoulda'
require 'base64'

class Api::AssignmentsControllerTest < ActionController::TestCase

  # Testing unauthenticated requests
  context 'An unauthenticated request to api/assignments' do
    setup do
      # Set garbage HTTP header
      @request.env['HTTP_AUTHORIZATION'] = 'garbage http_header'
      @request.env['HTTP_ACCEPT'] = 'application/xml'
    end

    context '/index' do
      setup do
        get 'index'
      end

      should 'fail to authenticate the GET request' do
        assert_response 403
      end
    end

    context '/show' do
      setup do
        get 'show', :id => 1
      end

      should 'fail to authenticate the GET request' do
        assert_response 403
      end
    end

    context '/create' do
      setup do
        @res_create = post('create')
      end

      should 'fail to authenticate the GET request' do
        assert_response 403
      end
    end

    context '/update' do
      setup do
        put 'update', :id => 1
      end

      should 'fail to authenticate the GET request' do
        assert_response 403
      end
    end

    context '/destroy' do
      setup do
        delete 'destroy', :id => 1
      end

      should 'fail to authenticate the GET request' do
        assert_response 403
      end
    end
  end

  # Testing authenticated requests
  context 'An authenticated request to api/assignments' do
    setup do
      # Fixtures have manipulated the DB, clear them off.
      clear_fixtures

      # Create admin from blueprints
      @admin = Admin.make
      @admin.reset_api_key
      base_encoded_md5 = @admin.api_key.strip
      auth_http_header = "MarkUsAuth #{base_encoded_md5}"
      @request.env['HTTP_AUTHORIZATION'] = auth_http_header
      @request.env['HTTP_ACCEPT'] = 'application/xml'

      # Default XML elements displayed for assignments
      @default_xml = ['id', 'description', 'short-identifier', 'message', 'due-date', 
                      'group-min', 'group-max', 'tokens-per-day', 'allow-web-submits', 
                      'student-form-groups', 'remark-due-date', 'remark-message',
                      'assign-graders-to-criteria', 'enable-test', 'allow-remarks',
                      'display-grader-names-to-students', 'group-name-autogenerated',
                      'marking-scheme-type', 'repository-folder']
    end

    # Testing application/json response
    context 'getting a json response' do
      setup do
        @request.env['HTTP_ACCEPT'] = 'application/json'
        get 'show', :id => 'garbage'
      end

      should 'be successful' do
        assert_template 'shared/http_status'
        assert_equal @response.content_type, 'application/json'
      end
    end

    # Testing application/xml response
    context 'getting an xml response' do
      setup do
        @request.env['HTTP_ACCEPT'] = 'application/xml'
        get 'show', :id => 'garbage'
      end

      should 'be successful' do
        assert_template 'shared/http_status'
        assert_equal @response.content_type, 'application/xml'
      end
    end

    # Testing an invalid HTTP_ACCEPT type
    context 'getting an rss response' do
      setup do
        @request.env['HTTP_ACCEPT'] = 'application/rss'
        get 'show', :id => 'garbage'
      end

      should 'not be successful' do
        assert_not_equal @response.content_type, 'application/rss'
      end
    end

    # Testing GET api/assignments
    context 'testing index function' do
      # Create three test assignments
      setup do
        @assignment1 = Assignment.make(:short_identifier => 'A1', 
          :due_date => '2012-03-20 23:59:00', :group_min => 1)
        @assignment2 = Assignment.make(:short_identifier => 'A2', 
          :due_date => '2012-03-21 23:59:00', :group_min => 2, :message => 'test')
        @assignment3 = Assignment.make(:short_identifier => 'A3', 
          :due_date => '2012-03-22 23:59:00', :group_min => 2)
      end

      should 'get all assignments in the collection if no options are used' do
        get 'index'
        assert_response :success
        assert_select 'assignment', Assignment.all.size
      end

      should 'get only first 2 assignments if a limit of 2 is provided' do
        get 'index', :limit => '2'
        assert_response :success
        assert_select 'assignment', 2
        assert @response.body.include?(@assignment1.short_identifier)
        assert @response.body.include?(@assignment2.short_identifier)
      end

      should 'get 2 later assignments if a limit of 2 and offset of 1 is used' do
        get 'index', :limit => '2', :offset => '1'
        assert_response :success
        assert_select 'assignment', 2
        assert @response.body.include?(@assignment2.short_identifier)
        assert @response.body.include?(@assignment3.short_identifier)
      end

      should 'get only matching assignments if a valid filter is used' do
        get 'index', :filter => 'group_min:2'
        assert_response :success
        assert_select 'assignment', 2
        assert @response.body.include?(@assignment2.short_identifier)
        assert @response.body.include?(@assignment3.short_identifier)
      end

      should 'get only matching assignments if multiple valid filters are used' do
        get 'index', :filter => 'group_min:2,message:test'
        assert_response :success
        assert_select 'assignment', 1
        assert @response.body.include?(@assignment2.short_identifier)
      end

      should 'ignore invalid filters' do
        get 'index', :filter => 'group_min:2,badfilter:invalid'
        assert_response :success
        assert_select 'assignment', 2
        assert @response.body.include?(@assignment2.short_identifier)
        assert @response.body.include?(@assignment3.short_identifier)
      end

      should 'apply limit/offset after the filter' do
        get 'index', :filter => 'group_min:2', :limit => '1', :offset => '1'
        assert_response :success
        assert_select 'assignment', 1
        assert @response.body.include?(@assignment3.short_identifier)
      end

      should 'display all default fields if the fields parameter is not used' do
        get 'index'
        assert_response :success
        @default_xml.each do |element|
          assert_select element, {:minimum => 1}
        end
      end

      should 'only display specified fields if the fields parameter is used' do
        get 'index', :fields => 'short_identifier,due_date'
        assert_response :success
        assert_select 'short-identifier', {:minimum => 1}
        assert_select 'due-date', {:minimum => 1}
        elements = Array.new(@default_xml)
        elements.delete('short-identifier')
        elements.delete('due-date')
        elements.each do |element|
          assert_select element, 0
        end
      end

      should 'ignore invalid fields provided in the fields parameter' do
        get 'index', :fields => 'short_identifier,invalid_field_name'
        assert_response :success
        assert_select 'short-identifier', {:minimum => 1}
        elements = Array.new(@default_xml)
        elements.delete('short-identifier')
        elements.each do |element|
          assert_select element, 0
        end
      end
    end

    # Testing GET api/assignments/:id
    context 'testing show function' do
      setup do
        @assignment = Assignment.make(:short_identifier => 'A1', 
          :due_date => '2012-03-20 23:59:00', :group_min => 1)
      end

      should 'return only that assignment and default attributes if valid id' do
        get 'show', :id => @assignment.id.to_s
        assert_response :success
        assert @response.body.include?(@assignment.short_identifier)
        @default_xml.each do |element|
          assert_select element, 1
        end
      end

      should 'return only that assignment and specified fields if provided' do
        get 'show', :id => @assignment.id.to_s, :fields => 'id,due_date'
        assert_response :success
        assert @response.body.include?(@assignment.id.to_s)
        assert_select 'id', 1
        assert_select 'due-date', 1
        elements = Array.new(@default_xml)
        elements.delete('id')
        elements.delete('due-date')
        elements.each do |element|
          assert_select element, 0
        end
      end

      should "return a 404 if an assignment with a numeric id doesn't exist" do
        get 'show', :id => '9999'
        assert_response 404
      end

      should 'return a 422 if the provided id is not strictly numeric' do
        get 'show', :id => '9a'
        assert_response 422
      end
    end

    # Testing POST api/assignments
    context 'testing the create function with minimal valid attributes' do
      setup do
        # Create parameters for request and send
        post 'create', :short_identifier => 'test1', :description => 'sample',
          :message => 'sample2', :due_date => '2013-04-07 23:00:01'
      end

      should 'create the specified assignment' do
        assert_response 201
        @assignment = Assignment.find_by_short_identifier('test1')
        assert !@assignment.nil?
        assert_equal(@assignment.short_identifier, 'test1')
        assert_equal(@assignment.description, 'sample')
        assert_equal(@assignment.message, 'sample2')
      end
    end

    context 'testing the create function with all attributes' do
      setup do
        @attr = { :short_identifier => 'TestAs', :message => 'Test Message',
                  :description => 'Test', :due_date => '2012-03-26 18:04:39', 
                  :tokens_per_day => 13,  :repository_folder => 'Folder',
                  :marking_scheme_type => 'flexible', :allow_web_submits => false,
                  :display_grader_names_to_students => true, :enable_test => true,
                  :assign_graders_to_criteria => true, :student_form_groups => true,
                  :group_name_autogenerated => false, :submission_rule_deduction => 10,
                  :submission_rule_hours => 11, :submission_rule_interval => 12, 
                  :remark_due_date => '2012-03-26 18:04:39', :group_max => 3,
                  :submission_rule_type => 'PenaltyDecayPeriod', :group_min => 2,
                  :remark_message => 'Remark', :allow_remarks => false }
        post 'create', @attr
      end

      should 'create the new assignment' do
        assert_response :success
        @assignment = Assignment.find_by_short_identifier(@attr[:short_identifier])
        assert !@assignment.nil?
        @attr.each do |key, val|
          # submission rule attributes and dates are special cases
          if key.to_s.include? 'date'
            assert_equal(Time.zone.parse(@attr[key]), @assignment[key])
          elsif !key.to_s.include? 'submission_rule'
            assert_equal(@attr[key], @assignment[key])
          end
        end

        sub_rule = @assignment.submission_rule
        assert_equal(sub_rule.type, PenaltyDecayPeriodSubmissionRule.to_s)
        assert_equal(sub_rule.periods.first.deduction, @attr[:submission_rule_deduction])
        assert_equal(sub_rule.periods.first.hours, @attr[:submission_rule_hours])
        assert_equal(sub_rule.periods.first.interval, @attr[:submission_rule_interval])
      end
    end

    context 'testing create with a taken short_identifier' do
      setup do
        @assignment = Assignment.make
        post 'create', :short_identifier => @assignment.short_identifier, 
          :description => 'sample', :due_date => '2013-04-07 23:00:01'
      end

      should 'find an existing assignment and cause conflict' do
        assert !Assignment.find_by_short_identifier(@assignment.short_identifier).nil?
        assert_response :conflict
      end
    end

    context 'testing the create function with an invalid due_date' do
      setup do
        post 'create', :short_identifier => 'RandomAs', 
          :description => 'sample2', :due_date => 'garbage'
      end

      should 'not be able to process the date' do
        assert_response 500
      end
    end

    context 'testing create with an invalid submission rule' do
      setup do
        post 'create', :short_identifier => 'RandomAs', :description => 'sample2', 
          :due_date => '2012-03-26 18:04:39', :message => 'Test Message',
          :submission_rule_type => 'PenaltyDecayPeriod', :enable_test => true,
          :submission_rule_deduction => 10, :submission_rule_interval => 'A'
      end

      should 'not be able to create the rule or assignment' do
        assert_response 500
      end
    end

  end
end
