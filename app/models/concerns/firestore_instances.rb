module FirestoreInstances
  extend ActiveSupport::Concern

  ACCEPTED_DOCUMENT_FORMATS = [Google::Cloud::Firestore::DocumentSnapshot, Google::Cloud::Firestore::DocumentReference]

  included do

    ##
    # Firestore document & querying methods
    ##

    def self.client
      ApplicationController.firestore_client
    end

    def self.collection
      self.client.col(self.collection_name)
    end

    def reference
      self.document.reference
    end

    def document_id
      self.document.document_id
    end

    def sub_documents
      self.reference.col(self.class.sub_collection_name)
    end

    def self.count(query={})
      if query.empty?
        self.collection.get.count
      else
        collection_ref = self.collection
        query.each do |attr, val|
          collection_ref = collection_ref.where(attr.to_sym, :==, val)
        end
        collection_ref.get.count
      end
    end

    def self.exists?(query={})
      if query.empty?
        false
      else
        self.count(query) > 0
      end
    end

    def self.query_by(query={})
      collection_ref = self.collection
      query.each do |attr, val|
        collection_ref = collection_ref.where(attr.to_sym, :==, val)
      end
      collection_ref.get
    end

    ##
    # Attribute getter/setter
    ##

    def initialize(document_snapshot)
      unless ACCEPTED_DOCUMENT_FORMATS.include? document_snapshot.class
        raise ArgumentError, "invalid Firestore document instance: #{document_snapshot.class.name}, must be in #{ACCEPTED_DOCUMENT_FORMATS}"
      end

      if document_snapshot.is_a?(Google::Cloud::Firestore::DocumentSnapshot)
        self.document = document_snapshot
      elsif document_snapshot.is_a?(Google::Cloud::Firestore::DocumentReference)
        self.document = document_snapshot.get
      end

      # assign only values that are declared as attr_accessor for given model
      self.document.data.each do |attribute, value|
        attr_method = "#{attribute}=".to_sym # will be a built-in from ActiveModel::AttributeAssignment
        if self.respond_to?(attr_method)
          self.send(attr_method, value)
        end
      end
    end

    def attributes
      attrs = {}
      self.instance_variable_names.each do |var_name|
        # omit document as this is just a placeholder to point back to Firestore - we really only want what appears
        # in the "data" for the document, not the document itself
        unless var_name == "@document"
          formatted_name = var_name.gsub(/@/, '') # remove '@' sign from variable name for parity with attributes method
          attrs.merge!({formatted_name => self.instance_variable_get(var_name)})
        end
      end
      attrs
    end

    def study_file
      StudyFile.find(self.file_id)
    end

  end
end
