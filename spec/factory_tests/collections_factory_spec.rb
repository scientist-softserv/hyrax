# frozen_string_literal: true
RSpec.describe 'Collections Factory' do # rubocop:disable RSpec/DescribeClass
  let(:user) { build(:user, email: 'user@example.com') }
  let(:user_mgr) { build(:user, email: 'user_mgr@example.com') }
  let(:user_dep) { build(:user, email: 'user_dep@example.com') }
  let(:user_vw) { build(:user, email: 'user_vw@example.com') }
  let(:collection_type) { create(:collection_type) }

  describe 'build' do
    context 'with collection_type_settings and/or collection_type_gid' do
      it 'will use the default User Collection type when neither is specified' do
        col = build(:collection_lw)
        expect(col.collection_type.title).to eq 'User Collection'
        expect(col.collection_type.machine_id).to eq 'user_collection'
      end

      it 'uses collection type for passed in collection_type_gid when collection_type_settings is nil' do
        col = build(:collection_lw, collection_type_gid: collection_type.to_global_id.to_s)
        expect(col.collection_type_gid).to eq collection_type.to_global_id.to_s
      end

      it 'ignores collection_type_gid when collection_type_settings is set to attributes identifying settings' do
        col = build(:collection_lw, collection_type_settings: [:not_discoverable, :not_sharable], collection_type_gid: collection_type.to_global_id.to_s)
        expect(col.collection_type_gid).not_to eq collection_type.to_global_id.to_s
      end

      it 'will create a collection type when collection_type_settings is set to attributes identifying settings' do
        expect { build(:collection_lw, collection_type_settings: [:discoverable]) }.to change { Hyrax::CollectionType.count }.by(1)
        expect { build(:collection_lw, collection_type_settings: [:not_discoverable, :not_sharable]) }.to change { Hyrax::CollectionType.count }.by(1)
      end

      it 'will create a collection type with specified settings when collection_type_settings is set to attributes identifying settings' do
        col = build(:collection_lw, collection_type_settings: [:not_discoverable, :not_sharable, :not_brandable, :nestable])
        collection_type = Hyrax::CollectionType.for(collection: col)
        expect(collection_type.discoverable?).to be false
        expect(collection_type.sharable?).to be false
        expect(collection_type.brandable?).to be false
        expect(collection_type.nestable?).to be true
      end
    end

    context 'with_permission_template' do
      it 'will not create a permission template or access when it is the default value of false' do
        expect { build(:collection_lw) }.not_to change { Hyrax::PermissionTemplate.count }
        expect { build(:collection_lw) }.not_to change { Hyrax::PermissionTemplateAccess.count }
      end

      it 'will create a permission template and one access for the creating user when set to true' do
        expect { build(:collection_lw, with_permission_template: true) }.to change { Hyrax::PermissionTemplate.count }.by(1)
        expect { build(:collection_lw, with_permission_template: true) }.to change { Hyrax::PermissionTemplateAccess.count }.by(1)
      end

      it 'will create a permission template and access for each user specified when it is set to attributes identifying access' do
        expect { build(:collection_lw, with_permission_template: { manage_users: [user_mgr] }) }.to change { Hyrax::PermissionTemplate.count }.by(1)
        expect { build(:collection_lw, with_permission_template: { manage_users: [user_mgr] }) }.to change { Hyrax::PermissionTemplateAccess.count }.by(2)
        expect { build(:collection_lw, with_permission_template: { manage_users: [user_mgr], deposit_users: [user_dep], view_users: [user_vw] }) }
          .to change { Hyrax::PermissionTemplate.count }.by(1)
        expect { build(:collection_lw, with_permission_template: { manage_users: [user_mgr], deposit_users: [user_dep], view_users: [user_vw] }) }
          .to change { Hyrax::PermissionTemplateAccess.count }.by(4)
      end
    end

    context 'with_solr_document' do
      it 'will not create a solr document by default' do
        col = build(:collection_lw)
        expect(col.id).to eq nil # no real way to confirm a solr document wasn't created if the collection doesn't have an id
      end

      context 'true' do
        let(:col) { build(:collection_lw, with_solr_document: true) }

        subject { Hyrax::SolrService.get("id:#{col.id}")["response"]["docs"].first }

        it 'will create a solr document' do
          expect(subject["id"]).to eq col.id
          expect(subject["has_model_ssim"].first).to eq "Collection"
          expect(subject["edit_access_person_ssim"]).not_to be_blank
        end
      end

      context 'true and with_permission_template defines additional access' do
        let(:col) do
          build(:collection_lw, user: user,
                                with_solr_document: true,
                                with_permission_template: { manage_users: [user_mgr],
                                                            deposit_users: [user_dep],
                                                            view_users: [user_vw] })
        end

        subject { Hyrax::SolrService.get("id:#{col.id}")["response"]["docs"].first }

        it 'will create a solr document' do
          expect(subject["id"]).to eq col.id
          expect(subject["has_model_ssim"].first).to eq "Collection"
          expect(subject["edit_access_person_ssim"]).to include(user.user_key, user_mgr.user_key)
          expect(subject["read_access_person_ssim"]).to include(user_dep.user_key, user_vw.user_key)
        end
      end
    end
  end

  describe 'create' do
    # collection_type_settings and collection_type_gid are tested by `build` and are the same for `build` and `create`
    # with_solr_document is tested by build
    # with_permission_template is tested by build except that the permission template is always created for `create`

    context 'with_permission_template' do
      it 'will create a permission template and access even when it is the default value of false' do
        expect { create(:collection_lw) }.to change { Hyrax::PermissionTemplate.count }.by(1)
        expect { create(:collection_lw) }.to change { Hyrax::PermissionTemplateAccess.count }.by(1)
      end
    end
  end
end
