/*
 * Copyright 2016 Realm Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package io.realm.realmtasks;

import android.content.Intent;
import android.os.Bundle;
import android.support.v7.app.AppCompatActivity;
import android.support.v7.widget.LinearLayoutManager;
import android.support.v7.widget.RecyclerView;
import android.view.Menu;
import android.view.MenuItem;

import io.realm.Realm;
import io.realm.realmtasks.list.ItemViewHolder;
import io.realm.realmtasks.list.TaskAdapter;
import io.realm.realmtasks.list.TouchHelper;
import io.realm.realmtasks.model.TaskList;

public class TaskActivity extends AppCompatActivity {

    public static final String EXTRA_ID = "extra.id";

    private Realm realm;
    private RecyclerView recyclerView;
    private TaskAdapter adapter;
    private TouchHelper touchHelper;
    private String id;

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_common_list);
        recyclerView = (RecyclerView) findViewById(R.id.recycler_view);
        recyclerView.setLayoutManager(new LinearLayoutManager(this));
        final Intent intent = getIntent();
        if (!intent.hasExtra(EXTRA_ID)) {
            throw new IllegalArgumentException(EXTRA_ID + " required");
        }
        id = intent.getStringExtra(EXTRA_ID);
    }

    @Override
    protected void onStart() {
        super.onStart();
        realm = Realm.getDefaultInstance();
        TaskList list = realm.where(TaskList.class).equalTo("id", id).findFirst();
        if (list.isValid()) {
            setTitle(list.getText());
            adapter = new TaskAdapter(this, list.getItems());
            touchHelper = new TouchHelper(new Callback(), adapter);
            touchHelper.attachToRecyclerView(recyclerView);
        } else {
            setTitle(getString(R.string.title_deleted));
            // TODO Handle that list was deleted
        }
    }

    @Override
    protected void onStop() {
        if (adapter != null) {
            touchHelper.attachToRecyclerView(null);
            recyclerView.setAdapter(null);
        }
        realm.close();
        super.onStop();
    }

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        getMenuInflater().inflate(R.menu.menu_tasks, menu);
        return true;
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        switch(item.getItemId()) {
            case R.id.action_logout:
                Intent intent = new Intent(TaskActivity.this, SignInActivity.class);
                intent.setAction(SignInActivity.ACTION_LOGOUT_EXISTING_USER);
                startActivity(intent);
                realm.close();
                finish();
                return true;

            default:
                return super.onOptionsItemSelected(item);
        }
    }

    private class Callback implements TouchHelper.Callback {

        @Override
        public void onMoved(RecyclerView recyclerView, ItemViewHolder from, ItemViewHolder to) {
            final int fromPosition = from.getAdapterPosition();
            final int toPosition = to.getAdapterPosition();
            adapter.onItemMoved(fromPosition, toPosition);
            adapter.notifyItemMoved(fromPosition, toPosition);
        }

        @Override
        public void onArchived(ItemViewHolder viewHolder) {
            adapter.onItemArchived(viewHolder.getAdapterPosition());
            adapter.notifyDataSetChanged();
        }

        @Override
        public void onDismissed(ItemViewHolder viewHolder) {
            final int position = viewHolder.getAdapterPosition();
            adapter.onItemDismissed(position);
            adapter.notifyItemRemoved(position);
        }

        @Override
        public boolean canDismissed() {
            return true;
        }

        @Override
        public boolean onClicked(ItemViewHolder viewHolder) {
            return false;
        }

        @Override
        public void onChanged(ItemViewHolder viewHolder) {
            adapter.onItemChanged(viewHolder);
            adapter.notifyItemChanged(viewHolder.getAdapterPosition());
        }

        @Override
        public void onAdded() {
            adapter.onItemAdded();
            adapter.notifyItemInserted(0);
        }

        @Override
        public void onReverted(boolean shouldUpdateUI) {
            adapter.onItemReverted();
            if (shouldUpdateUI) {
                adapter.notifyDataSetChanged();
            }
        }

        @Override
        public void onExit() {
            finish();
        }
    }
}
