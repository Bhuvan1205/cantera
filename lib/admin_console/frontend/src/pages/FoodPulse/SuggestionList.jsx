import React, { useState, useEffect } from 'react';
import { getVendorDashboard } from '../../api/foodpulse';
import { Alert, LoadingSpinner } from '../../components/common/Feedback';

const formatSection = (category) => {
  if (!category) return 'General';
  const lower = category.toLowerCase();
  if (lower === 'bakery') return 'Bakery';
  if (lower === 'mess') return 'Mess';
  if (lower === 'continental') return 'Continental';
  if (lower === 'beverages') return 'Beverages';
  return category.charAt(0).toUpperCase() + category.slice(1);
};

export default function SuggestionList() {
  const [data, setData] = useState(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState(null);

  const fetchSuggestions = async () => {
    setIsLoading(true);
    setError(null);
    try {
      const res = await getVendorDashboard();
      setData(res);
    } catch (err) {
      setError(err.message || 'Failed to load suggestions');
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchSuggestions();
  }, []);

  if (isLoading) return <LoadingSpinner label="Loading Student Suggestions..." />;

  const pending = data?.pending_suggestions || [];
  const approved = data?.approved_suggestions || [];
  const suggestions = [...pending, ...approved];

  return (
    <div className="p-lg md:p-xl space-y-xl max-w-7xl mx-auto">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-display-sm font-bold text-on-surface">Student Food Suggestions</h1>
          <p className="text-body-md text-on-surface-variant">Food items suggested by students and their corresponding canteen section.</p>
        </div>
      </div>

      {error && <Alert type="error" message={error} />}

      <div className="bg-surface-container-lowest rounded-2xl border border-outline-variant/30 p-lg shadow-sm">
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse">
            <thead>
              <tr className="border-b border-outline-variant/30 text-body-sm text-on-surface-variant">
                <th className="py-sm px-md font-bold">Item Name</th>
                <th className="py-sm px-md font-bold">Section</th>
                <th className="py-sm px-md font-bold">Number of Requests</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-outline-variant/10 text-body-md">
              {suggestions.map((item) => (
                <tr key={item.id} className="hover:bg-surface-container-low/40">
                  <td className="py-sm px-md font-medium text-on-surface">{item.name}</td>
                  <td className="py-sm px-md font-semibold text-on-surface-variant">{formatSection(item.category)}</td>
                  <td className="py-sm px-md font-bold text-primary">
                    {item.request_count || 1} requests
                  </td>
                </tr>
              ))}
              {suggestions.length === 0 && (
                <tr>
                  <td colSpan="3" className="py-md text-center text-on-surface-variant italic">
                    No student suggestions submitted yet.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
