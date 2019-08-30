module FirestoreDocuments

  ##
  # FirestoreDocuments: Module to provide an interface between Rails and Firestore documents.  Allows adding class &
  # instance methods so the Firetore documents behave exactly like the original Mongoid models they are replacing
  ##

  extend ActiveSupport::Concern

  ACCEPTED_DOCUMENT_FORMATS = [Google::Cloud::Firestore::DocumentSnapshot, Google::Cloud::Firestore::DocumentReference]

  included do

    ##
    # Patch for using with Delayed::Job
    ##
    def persisted?
      true
    end

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

    def self.query_by(query={}, limit=nil)
      collection_ref = self.collection
      query.each do |attr, val|
        collection_ref = collection_ref.where(attr.to_sym, :==, val)
      end
      if limit.present?
        collection_ref = collection_ref.limit(limit.to_i)
      end
      collection_ref.get
    end

    def self.by_study(accession)
      documents = self.query_by(study_accession: accession)
      documents.map {|doc| self.new(doc)}
    end

    def self.by_study_and_name(accession, name)
      doc_ref = self.query_by(study_accession: accession, name: name)
      doc_ref.any? ? self.new(doc_ref.first) : nil
    end

    def self.by_study_and_file_id(accession, file_id)
      documents = self.query_by(study_accession: accession, file_id: file_id)
      documents.map {|doc| self.new(doc)}
    end

    # shortcut method to determine if there are any documents of this type for a study
    # useful for methods like @study.has_expression_data?
    # will limit to only a single document to cut down on query costs
    def self.study_has_any?(accession)
      self.query_by(study_accession: accession).any?
    end

    ##
    # Delete methods
    ##

    def self.delete_by_study(accession, threads=10)
      delete_documents(self.query_by(study_accession: accession), threads)
    end

    def self.delete_by_study_and_file(accession, file_id, threads=10)
      delete_documents(self.query_by(study_accession: accession, file_id: file_id), threads)
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

    private

    # clean up all documents and sub-documents, using base Firestore classes rather than
    # FirestoreDocument interface for better performance
    def self.delete_documents(documents, threads)
      Parallel.map(documents, in_threads: threads) do |doc|
        if self.respond_to?(:sub_collection)
          doc.sub_documents.get.each do |sub_doc|
            sub_doc.ref.delete
          end
        end
        doc.ref.delete
      end
    end
  end
end
