module VCR
  # @private
  class RequestHandler
    def handle
      invoke_before_request_hook

      return on_ignored_request    if should_ignore?
      return on_stubbed_request    if stubbed_response
      return on_recordable_request if VCR.real_http_connections_allowed?
      on_connection_not_allowed
    end

    def typed_request
      @typed_request ||= VCR::Request::Typed.apply_to(vcr_request, request_type)
    end

  private

    def request_type
      @request_type ||= case
        when should_ignore?                     then :ignored
        when stubbed_response                   then :stubbed
        when VCR.real_http_connections_allowed? then :recording
        else                                         :unhandled
      end
    end

    def invoke_before_request_hook
      return if disabled?
      VCR.configuration.invoke_hook(:before_http_request, typed_request)
    end

    def invoke_after_request_hook(vcr_response)
      return if disabled?
      VCR.configuration.invoke_hook(:after_http_request, typed_request, vcr_response)
    end

    def should_ignore?
      disabled? || VCR.request_ignorer.ignore?(vcr_request)
    end

    def disabled?
      VCR.library_hooks.disabled?(library_name)
    end

    def stubbed_response
      @stubbed_response ||= VCR.http_interactions.response_for(vcr_request)
    end

    def library_name
      # extracts `:typhoeus` from `VCR::LibraryHooks::Typhoeus::RequestHandler`
      @library_name ||= self.class.name.split('::')[-2].downcase.to_sym
    end

    # Subclasses can implement these
    def on_ignored_request
    end

    def on_stubbed_request
    end

    def on_recordable_request
    end

    def on_connection_not_allowed
      raise VCR::Errors::UnhandledHTTPRequestError.new(vcr_request)
    end
  end
end
